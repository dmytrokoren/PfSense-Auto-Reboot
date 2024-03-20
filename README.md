# PfSense-Auto-Reboot (Tested on pfSense 2.7.2)

A straightforward script designed to reboot your pfSense box when it is not connected to the internet.
Note: https://healthchecks.io account must be setup.

- Copy the script to the local pfsense router.

  1. Login via ssh using root user and password.

  2. Select shell command `8`.

  3. Change your directory to /usr/local/bin.

  ```
  cd /usr/local/bin
  ```

  4. Download the script file.

  ```
  curl -LJO https://raw.githubusercontent.com/dmytrokoren/PfSense-Auto-Reboot/main/PfReboot_hc.sh
  ```

  5. Install nano file editor

  ```
  pkg update
  pkg install nano
  ```

  6. Change your wan adapter name, if required (mine is re0), update iterations, sleep time, and hcUUID values using nano

  ```
  nano PfReboot_hc.sh
  ```

  7. (OPTONAL) Change the script to customize your experience.

     - Change the public ip of cloudflare to your liking (public server). But make sure it is a always on public ip address and does respond to ping (ICMP).
     - Uncomment the print lines. if you want to see feedback on the console. But by-default it is off.

  8. After Pasting the Script. Press `ESC` then `:x` to exit from the vi editor.

- To test the script on your local pfsense box (adjust the iterations and sleep time for quicker test).

  1. Install bash, if not installed already.

  ```
  pkg install bash
  ```

  2. Change permisson to executable.

  ```
  chmod +x PfReboot_hc.sh
  ```

  3. Run it as "bash PfReboot_hc.sh".

  ```
  bash PfReboot_hc.sh
  ```

- To run the the script on your local pfsence box on schedule.

  1. Install cron, if not installed already.

  System > Package Manager > Available Packages > Search "cron" > install.

  2. Configure the cron service.

  Services > corn > add

  Then type as follows
  (I'm setting cron job for every 5 mins, as I have set iterations: 5, timeInSeconds: 60)<br>
  This will ping the healthchecks.io once every 5 mins, but the ping check will occur every 1 minute.

        - Minute - */5
        - Hour - *
        - Day of the month - *
        - Month of the year - *
        - Day of the week - *
        - User -  root
        - Command - ``` bash /usr/local/bin/PfReboot_hc.sh ```

  3. Click on Save.

Now we are done. You can sleep peacefully and dont have to press the reset button when the internet is goes down. It will automatically reboot itself within sometime of going offline.

Feedback is always welcome.
