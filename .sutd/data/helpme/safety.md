# Safety & Recovery

## redo — re-run last command
    ls /etc
    redo /var               # ls /var
    redo s/etc/var/         # sed replace

## safe-rm
Dangerous rm requires confirmation:
    rm -rf /tmp/x           # asks yes/no
    rm -rf /etc             # asks to type 'yes'

## remember
    remember API_KEY=abc    # auto-export next session
    remember                # list all
    remember -d API_KEY     # forget
