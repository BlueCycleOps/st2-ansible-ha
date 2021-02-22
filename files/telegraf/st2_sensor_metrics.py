#!/opt/stackstorm/st2/bin/python
import json
import os
import re
import six
import subprocess
import time

ST2_SENSOR_PACK_PATTERN = re.compile('--pack=([^ ]+)')
ST2_SENSOR_CLASS_PATTERN = re.compile('--class-name=([^ ]+)')

class St2SensorMetrics(object):

    def __init__(self, args={}):
        self.api_key = args.get('api_key')
        self.auth_token = args.get('auth_token')
        self.username = args.get('username')
        self.password = args.get('password')
        # inherit environment variables from the Bolt context to preserve things
        # like locale... otherwise we get errors from the StackStorm client.
        self.env = os.environ
        # force the locale to UTF8, otherwise we get warnings from the stackstorm side
        # and result in us not being able to parse JSON output
        self.env['LC_ALL'] = 'en_US.UTF-8'

        # prefer API key over auth tokens
        if self.api_key:
            self.env['ST2_API_KEY'] = self.api_key
        elif self.auth_token:
            self.env['ST2_AUTH_TOKEN'] = self.auth_token
        elif self.username and self.password:
            # auth on the command line with username/password
            cmd = ['st2', 'auth', '--only-token', '-p', self.password, self.username]
            stdout = self.exec_cmd(cmd)
            self.env['ST2_AUTH_TOKEN'] = stdout.rstrip()

    def exec_cmd(self, cmd):
        return subprocess.check_output(cmd,
                                       stderr=subprocess.STDOUT,
                                       env=self.env)

    def list_sensor_processes(self):
        output = self.exec_cmd(['pgrep', '-f', '-a', 'sensor_wrapper.py'])
        output = output.decode('utf-8')
        line_list = output.splitlines()
        running_sensors = []
        for line in line_list:
            pack = ''
            clazz = ''
            line_parts = line.split(' ', 1)
            pid = line_parts[0]
            cmdline = line_parts[1]

            match = ST2_SENSOR_PACK_PATTERN.search(line)
            if match:
                pack = match.group(1)
            match = ST2_SENSOR_CLASS_PATTERN.search(line)
            if match:
                clazz = match.group(1)
            sensor_ref = '{}.{}'.format(pack, clazz)
            running_sensors.append({
                'sensor_ref': sensor_ref,
                'pid': pid,
                'cmdline': cmdline,
            })
        return running_sensors

    def list_st2_sensors(self):
        output = self.exec_cmd(['st2', 'sensor', 'list', '--json'])
        data = json.loads(output)
        st2_sensors = {}
        for sensor in data:
            st2_sensors[sensor['ref']] = {
                'enabled': sensor['enabled'],
                'running': False,
                'instances': [],
            }
        return st2_sensors

    def create_influx_metrics(self, st2_sensors, running_sensors):
        aggregated_sensors = st2_sensors
        for sensor in running_sensors:
            aggregated_sensors[sensor['sensor_ref']]['running'] = True
            aggregated_sensors[sensor['sensor_ref']]['instances'].append(sensor)

        metrics = []
        timestamp = self.get_influxdb_timestamp_ns()
        for ref, sensor in six.iteritems(aggregated_sensors):
            if sensor['running']:
                for inst in sensor['instances']:
                    metrics.append(('st2sensor_instances,ref={ref},enabled_tag={enabled},running_tag={running}'
                                ' running={running},enabled={enabled},pid={pid},cmdline={cmdline}'
                                ' {timestamp}').format(
                                    ref=ref,
                                    running=(1 if sensor['running'] else 0),
                                    enabled=(1 if sensor['enabled'] else 0),
                                    pid=inst['pid'],
                                    # use JSON module to escape our quotes for us
                                    cmdline=json.dumps(inst['cmdline']),
                                    timestamp=timestamp,
                                )
                    )

            else:
                metrics.append(('st2sensor_instances,ref={ref},enabled_tag={enabled},running_tag={running}'
                            ' running={running},enabled={enabled}'
                            ' {timestamp}').format(
                                ref=ref,
                                running=(1 if sensor['running'] else 0),
                                enabled=(1 if sensor['enabled'] else 0),
                                timestamp=timestamp,
                            )
                )
        return '\n'.join(metrics)

    def get_influxdb_timestamp_ns(self):
        # time.time() returns a decimal in the format '1499350967.016834'
        # InfluxDB uses 19 digit integers as timestamps
        timestamp = int(float(format(time.time(), '.9f')) * 1000000000)
        return timestamp

    def run(self):
        st2_sensors = self.list_st2_sensors()
        running_sensors = self.list_sensor_processes()
        return self.create_influx_metrics(st2_sensors=st2_sensors,
                                          running_sensors=running_sensors)


if __name__ == '__main__':
    metrics = St2SensorMetrics()
    print(metrics.run())
