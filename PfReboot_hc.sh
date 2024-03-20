#!/bin/bash

#==================================================================
# description     :Script monitors primary and secondary DNS pings.
#                  If an issue arises, it temporarily resets the
#                  WAN interface and, if needed, triggers a system
#                  reboot, accompanied by a Telegram notification.
#                  The health check feature is integrated with the
#                  auto reboot functionality.
#==================================================================

# Set your healthchecks.io parameters
hcPingDomain="https://hc-ping.com/"
hcUUID=""

output=$({

    counter_file="/usr/local/bin/PfReboot_count.txt"

    # Function to be executed on error or termination
    cleanup() {
        echo "ready" >>"$counter_file"
        exit 1
    }

    # Set up a trap to catch ERR and SIGINT signals
    trap cleanup ERR INT

    # Check if the file exists and set values
    if [ ! -e "$counter_file" ]; then
        echo "0" >"$counter_file"
        echo "ready" >>"$counter_file"
    fi

    # Read the second line of the file
    current_status=$(sed -n '2p' "$counter_file")

    # Check if the second line contains "ready"
    if [[ -z "$current_status" || "$current_status" != "ready" ]]; then
        #echo "The current status inside of counter_file does not contain 'ready'. Exiting the script."

        # Uncomment the following lines if you want feedback on the console
        #echo "The current status is not 'ready'. Exiting the script." >>pfreboot_status.txt
        #wall pfreboot_status.txt
        #rm pfreboot_status.txt
        exit 22
    fi

    # Remove the second line from the counter_file
    awk 'NR!=2' "$counter_file" >temp_file && mv temp_file "$counter_file"

    # Max reboots before sleep
    max_reboots=2

    # Define the number of iterations and sleep time
    iterations=5
    timeInSeconds=60

    # Read the first line of the file
    current_count=$(head -n 1 "$counter_file" 2>/dev/null)

    # Increment and save counter function
    increment_counter() {
        current_count=$(head -n 1 "$counter_file" 2>/dev/null)
        [ -z "$current_count" ] && current_count=0
        ((current_count++))
        echo "$current_count" >"$counter_file"
    }

    update_status_state() {
        if ! grep -q "ready" "$counter_file"; then
            echo "ready" >>"$counter_file"
        fi
    }

    # Testing uptime to run script only xx seconds after boot

    # Current time
    currtime=$(date +%s)

    # Boot time in seconds
    utime=$(sysctl kern.boottime | awk -F'sec = ' '{print $2}' | awk -F',' '{print $1}')

    # Uptime in seconds
    utime=$(($currtime - $utime))

    # If boot is longer than 120 seconds ago... (To avoid bootloops)
    if [ $utime -gt 120 ]; then
        # Uncomment the following lines if you want feedback on the console
        #echo "Testing Connection at" $(date +%Y-%m-%d.%H:%M:%S) "uptime:" $utime "seconds" >>pfreboot_log.txt
        #wall pfreboot_log.txt
        #rm pfreboot_log.txt

        # Try 1 or 2 minutes worth of very short pings to Cloudflare public DNS servers
        # Quit immediately if we get a single frame back
        # If neither server responds at all, then reboot the firewall

        firstDNS="1.0.0.1"
        secondDNS="1.1.1.1"

        for i in $(seq 1 1 $iterations); do
            counting=$(ping -o -s 0 -c 10 $firstDNS | grep 'received' | awk -F',' '{ print $2 }' | awk '{ print $1 }')

            if [ $counting -eq 0 ]; then
                php -r 'require_once("/etc/inc/notices.inc"); notify_via_telegram("Ping to DNS server '$firstDNS' is unreachable");'

                counting=$(ping -o -s 0 -c 10 $secondDNS | grep 'received' | awk -F',' '{ print $2 }' | awk '{ print $1 }')

                if [ $counting -eq 0 ]; then
                    php -r 'require_once("/etc/inc/notices.inc"); notify_via_telegram("Ping to DNS server '$secondDNS' is unreachable");'

                    # Trying to restart NIC
                    # Change the NIC name as per your WAN
                    nic_name="re0"

                    php -r 'require_once("/etc/inc/notices.inc"); notify_via_telegram("Restarting WAN ('$nic_name')");'

                    ifconfig $nic_name down
                    ifconfig $nic_name up

                    # Check if re0 is up
                    while ! ifconfig $nic_name | grep -q "status: active"; do
                        sleep 1
                    done

                    sleep 10s

                    # Testing if a ping is successful
                    counting=$(ping -o -s 0 -c 10 $firstDNS | grep 'received' | awk -F',' '{ print $2 }' | awk '{ print $1 }')

                    if [ $counting -eq 0 ]; then
                        php -r 'require_once("/etc/inc/notices.inc"); notify_via_telegram("Ping to DNS server '$firstDNS' remains unreachable even after WAN ('$nic_name') restart");'

                        if [ "$current_count" -ge "$max_reboots" ]; then
                            php -r 'require_once("/etc/inc/notices.inc"); notify_via_telegram("The maximum number of reboots ('$max_reboots') has been reached. The system will wait for 1 hour before the next reboot interval");'

                            sleep 1h

                            # Reset the counter to 0
                            echo "0" >"$counter_file"
                        fi

                        # Increment counter and write to file
                        increment_counter

                        update_status_state

                        # Save RRD data
                        # Reboot the system
                        php -r 'require_once("/etc/inc/notices.inc"); notify_via_telegram("pfSense is rebooting now.");'
                        /etc/rc.backup_rrd.sh
                        reboot
                    fi
                fi
            fi

            sleep_duration=$(echo "$timeInSeconds - 0.02" | bc)

            if [ $i -eq 5 ]; then
                update_status_state
                sleep $sleep_duration
            else
                sleep $sleep_duration
            fi
        done
        update_status_state
    fi
} 2>&1)

# Exit status logic
exitStatus=${PIPESTATUS[0]}

if [[ "$exitStatus" != 22 ]]; then
    if [ -z "$output" ]; then
        curl -fsS --retry 3 "${hcPingDomain}${hcUUID}/${exitStatus}"
    else
        if [ "$exitStatus" -eq 0 ]; then
            curl -fsS --retry 3 --data-raw "${output}" "${hcPingDomain}${hcUUID}/fail"
        else
            curl -fsS --retry 3 --data-raw "${output}" "${hcPingDomain}${hcUUID}/${exitStatus}"
        fi
    fi
fi
