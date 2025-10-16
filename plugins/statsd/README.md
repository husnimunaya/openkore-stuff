# Statsd plugin for Openkore

This plugin sends OpenKore metrics to a StatsD server for monitoring and visualization.


## Configuration

Add the following settings to your `config.txt`:

```
statsd 1
statsd_host localhost     # your statsd server host
statsd_port 8125          # your statsd server port
statsd_prefix openkore    # metric prefix
```

## Dependencies

This plugin requires the `Net::Dogstatsd` Perl module. Install it using [cpanm](https://metacpan.org/dist/App-cpanminus/view/bin/cpanm):

```bash
cpanm Net::Dogstatsd
```

## Usage with Prometheus and Grafana

You can set up a monitoring stack using the provided docker compose file in the `examples` folder. The examples used statsd exporter to send the metrics to Prometheus, and then Grafana to visualize the metrics.

1. Navigate to the `examples` folder and run the docker compose:
  ```bash
  cd examples
  docker compose up -d
  ```
2. Wait for the containers to start and then you can access the Prometheus and Grafana web UIs at `http://localhost:9090` and `http://localhost:3000` respectively.

If you don't want to self host Grafana, you can use Grafana Cloud service (the free tier is enough for this use case).


## Available Metrics

* `monster_kill_duration_seconds`: The time taken to kill a monster (histogram).
* `damage_per_second`: The damage per second dealt to a monster (histogram).
* `skilluse_dmg`: The damage dealt to a monster with a skill (histogram).
* `attack_dmg`: The damage dealt to a monster with a normal attack per hit (histogram).

## Example PromQL Queries


## Example PromQL Queries

### Monster Kill Count
```promql
sum by (character, monster) (floor(increase(openkore_monster_kill_duration_seconds_count[5m])))
```

### Average Monster Kill Duration
```promql
sum by (character, monster) (rate(openkore_monster_kill_duration_seconds_sum[5m]) / rate(openkore_monster_kill_duration_seconds_count[5m]))
```

### Damage Per Second
```promql
sum by (character, monster) (rate(openkore_damage_per_second_sum[5m]) / rate(openkore_damage_per_second_count[5m]))
```
