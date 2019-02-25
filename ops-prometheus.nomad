job "prometheus" {
  datacenters               = ["[[env "DC"]]"]
  type = "service"
  group "prometheus" {
    update {
      stagger               = "10s"
      max_parallel          = "1"
    }
    count                   = "[[.promtheus.count]]"
    restart {
      attempts              = 5
      interval              = "5m"
      delay                 = "25s"
      mode                  = "delay"
    }
    task "prometheus" {
      kill_timeout          = "180s"
      logs {
        max_files           = 5
        max_file_size       = 10
      }
      template {
        data                = "{{key "prometheus/config"}}"
        destination         = "local/prometheus.yml"
        change_mode         = "signal"
        change_signal       = "SIGHUP"
      }
      template {
	data                = "{{key "prometheus/alert"}}"
	destination	    = "/local/prometheus-rules/alert.yml"
	change_mode	    = "signal"
	change_signal	    = "SIGHUP"
      }	
      driver                = "docker"
      config {
        logging {
            type            = "syslog"
            config {
              tag           = "${NOMAD_JOB_NAME}${NOMAD_ALLOC_INDEX}"
            }   
        }
	network_mode        = "host"
        force_pull          = true
        image               = "prom/prometheus:[[.prometheus.version]]"
        args                = ["--config.file=/local/prometheus.yml", "--web.enable-admin-api", "--storage.tsdb.retention=[[.prometheus.retention]]", "--web.external-url=[[.prometheus.url]]"]	
        hostname            = "${attr.unique.hostname}"
	dns_servers         = ["${attr.unique.network.ip-address}"]
        dns_search_domains  = ["consul","service.consul","node.consul"]
        volume_driver       = "rexray"
        volumes             = ["${attr.consul.datacenter}-prometheus-${NOMAD_ALLOC_INDEX}:/prometheus"]
      }
      resources {
        memory              = "[[.prometheus.ram]]"
        network {
          mbits = 100
          port "healthcheck" {
            static          = "[[.prometheus.port]]"
          }
        } #network
      } #resources
      service {
        name                = "prometheus"
        tags                = ["[[.prometheus.version]]"]
        port                = "healthcheck"
        check {
          name              = "prometheus-internal-port-check"
          port              = "healthcheck"
          type              = "tcp"
          interval          = "10s"
          timeout           = "2s"
        } #check
      } #service
    } #task
  } #group
} #job
