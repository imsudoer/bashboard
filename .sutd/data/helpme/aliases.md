# Alias Manager (al)

Save and run commands by name.

## Save
    al "systemctl restart nginx" rnginx

## Run
    al rnginx

## With arguments
    al "systemctl {1} {2}" sysctl
    sysctl restart nginx

## Manage
- `al` — list all
- `al <name> -e` — edit
- `al <name> -d` — delete
- `al -s docker` — search
