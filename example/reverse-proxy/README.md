# NGINX-LE - Nginx web and proxy with automatic let's encrypt [![Docker Automated build](https://img.shields.io/docker/automated/jrottenberg/ffmpeg.svg)](https://hub.docker.com/r/umputun/nginx-le/) 

Simple nginx image (alpine based) with integrated [Let's Encrypt](https://letsencrypt.org) support.

## Reverse proxy example

This example covers a popular topic of configuring a reverse proxy with nginx and letsencrypt for SSL. The example nginx configuration ```service.conf``` allows you to map public ports to internal hostnames and ports.

There are 2 sample services in ```docker-compose.yml```.
```service1``` exposes port ```8000``` and ```service2``` exposes port ```80```.
The nginx listens to ports ```443``` and ```8443``` and proxy requests to these services, effectively wrapping them with SSL. The nginx configuration file ```service.conf``` contains mappings between publically accessible ports, exposed on nginx itself, and private services names and their ports.

To debug the routing of your requests you can add the following section to ```service.conf```, which will add headers to http responses to identify the target host and port of the internal service.

```
server {
    ...
    add_header X-inthostname "$int_hostname";
    add_header X-intport "$int_port";
    ...
}
```

Always make sure that your docker-compose.yml exposes all the needed ports for nginx and always expose ports 80 and 443 just for Letsencrypt update to work properly.

## Running the example

- Edit ```docker-compose.yml``` to setup environment variables for LetsEncrypt as described in the main readme.
- Run the example with ```docker-compose up```
- Wait and check that nginx was able to acquire SSL certificates and reloaded with ssl enabled
- Detach using ```Ctrl-z```, then run ```bg``` to continue running the job
- Test if everything works as expected with curl: ```curl https://YOURDOMAIN.COM/``` and ```curl https://YOURDOMAIN.COM:8443/```. You should see proper responses from service1 and service2, over SSL on ports you've set up mappings for.

