# setting up some frequently used functions
check_euid(){
  if [ "$EUID" -eq 0 ]
  then
    echo -e "${red}"
    top_border
    echo -e "|       !!! THIS SCRIPT MUST NOT RAN AS ROOT !!!        |"
    bottom_border
    echo -e "${default}"
    exit 1
  fi
}

source_ini(){
  source ${HOME}/kiauh/kiauh.ini
}

start_klipper(){
  if [ -e /etc/init.d/klipper ]; then
    status_msg "Starting Klipper Service ..."
    sudo /etc/init.d/klipper start && sleep 2 && ok_msg "Klipper Service started!"
  fi
}

stop_klipper(){
  if [ -e /etc/init.d/klipper ]; then
    status_msg "Stopping Klipper Service ..."
    sudo /etc/init.d/klipper stop && sleep 2 && ok_msg "Klipper Service stopped!"
  fi
}

restart_klipper(){
  if [ -e /etc/init.d/klipper ]; then
    status_msg "Restarting Klipper Service ..."
    sudo /etc/init.d/klipper restart && sleep 2 && ok_msg "Klipper Service restarted!"
  fi
}

start_moonraker(){
  if [ -e /etc/init.d/moonraker ]; then
    status_msg "Starting Moonraker Service ..."
    sudo /etc/init.d/moonraker start && sleep 2 && ok_msg "Moonraker Service started!"
  fi
}

stop_moonraker(){
  if [ -e /etc/init.d/moonraker ]; then
    status_msg "Stopping Moonraker Service ..."
    sudo /etc/init.d/moonraker stop && sleep 2 && ok_msg "Moonraker Service stopped!"
  fi
}

restart_moonraker(){
  if [ -e /etc/init.d/moonraker ]; then
    status_msg "Restarting Moonraker Service ..."
    sudo /etc/init.d/moonraker restart && sleep 2 && ok_msg "Moonraker Service restarted!"
  fi
}

start_octoprint(){
  if [ -e /etc/init.d/octoprint ]; then
    status_msg "Starting OctoPrint Service ..."
    sudo /etc/init.d/octoprint start && sleep 2 && ok_msg "OctoPrint Service started!"
  fi
}

stop_octoprint(){
  if [ -e /etc/init.d/octoprint ]; then
    status_msg "Stopping OctoPrint Service ..."
    sudo /etc/init.d/octoprint stop && sleep 2 && ok_msg "OctoPrint Service stopped!"
  fi
}

restart_octoprint(){
  if [ -e /etc/init.d/octoprint ]; then
    status_msg "Restarting OctoPrint Service ..."
    sudo /etc/init.d/octoprint restart && sleep 2 && ok_msg "OctoPrint Service restarted!"
  fi
}

restart_nginx(){
  if [ -e /etc/init.d/nginx ]; then
    status_msg "Restarting Nginx Service ..."
    sudo /etc/init.d/nginx restart && sleep 2 && ok_msg "Nginx Service restarted!"
  fi
}

dependency_check(){
  status_msg "Checking for dependencies ..."
  #check if package is installed, if not write name into array
  for pkg in "${dep[@]}"
  do
    if [[ ! $(dpkg-query -f'${Status}' --show $pkg 2>/dev/null) = *\ installed ]]; then
      inst+=($pkg)
    fi
  done
  #if array is not empty, install packages from array elements
  if [ "${#inst[@]}" != "0" ]; then
    status_msg "Installing the following dependencies:"
    for element in ${inst[@]}
    do
      echo -e "${cyan}● $element ${default}"
    done
    echo
    sudo apt-get install ${inst[@]} -y
    ok_msg "Dependencies installed!"
    #clearing the array
    unset inst
  else
    ok_msg "Dependencies already met! Continue..."
  fi
}

print_error(){
  for data in "${data_arr[@]}"
  do
    if [ ! -e $data ]; then
      data_count+=(0)
    else
      data_count+=(1)
    fi
  done
  sum=$(IFS=+; echo "$((${data_count[*]}))")
  if [ $sum -eq 0 ]; then
    ERROR_MSG=" Looks like $1 was already removed!\n Skipping..."
  else
    ERROR_MSG=""
  fi
}

build_fw(){
    if [ -d $KLIPPER_DIR ]; then
      cd $KLIPPER_DIR && make menuconfig
      status_msg "Building Firmware ..."
      make clean && make && ok_msg "Firmware built!"
    else
      warn_msg "Can not build Firmware without a Klipper directory!"
    fi
}

### grab the printers id
get_usb_id(){
  warn_msg "Make sure your printer is the only USB device connected!"
  while true; do
    echo -e "${cyan}"
    read -p "###### Press any key to continue ... " yn
    echo -e "${default}"
    case "$yn" in
      *) break;;
    esac
  done
  status_msg "Identifying the correct USB port ..."
  USB_ID=$(ls /dev/serial/by-id/*)
  if [ -e /dev/serial/by-id/* ]; then
    status_msg "The ID of your printer is:"
    title_msg "$USB_ID"
  else
    warn_msg "Could not retrieve ID!"
    return 1
  fi
}

write_printer_id(){
  while true; do
    echo -e "${cyan}"
    read -p "###### Do you want to write the ID to your printer.cfg? (Y/n): " yn
    echo -e "${default}"
    case "$yn" in
      Y|y|Yes|yes|"")
        backup_printer_cfg
cat <<PRINTERID >> $PRINTER_CFG

##########################
### CREATED WITH KIAUH ###
##########################
[mcu]
serial: $USB_ID
##########################
##########################
PRINTERID
        ok_msg "Config written!"
        break;;
      N|n|No|no) break;;
    esac
  done
}

flash_routine(){
  echo -e "/=================================================\ "
  echo -e "|     ${red}~~~~~~~~~~~ [ ATTENTION! ] ~~~~~~~~~~~~${default}     |"
  echo -e "| Flashing a Smoothie based board for the first   |"
  echo -e "| time with this script will certainly fail.      |"
  echo -e "| This applies to boards like the BTT SKR V1.3 or |"
  echo -e "| the newer SKR V1.4 (Turbo). You have to copy    |"
  echo -e "| the firmware file to the microSD card manually  |"
  echo -e "| and rename it to 'firmware.bin'.                |"
  echo -e "|                                                 |"
  echo -e "| You find the file in: ~/klipper/out/klipper.bin |"
  echo -e "\=================================================/ "
  echo
  while true; do
    echo -e "${cyan}"
    read -p "###### Do you want to continue? (Y/n): " yn
    echo -e "${default}"
    case "$yn" in
      Y|y|Yes|yes|"")
      get_usb_id && flash_mcu && write_printer_id; break;;
      N|n|No|no) break;;
    esac
  done
}

flash_mcu(){
  stop_klipper
  if ! make flash FLASH_DEVICE="$USB_ID" ; then
    warn_msg "Flashing failed!"
    warn_msg "Please read the log above!"
  else
    ok_msg "Flashing successfull!"
  fi
  start_klipper
}

enable_octoprint_service(){
  if [[ -f $OCTOPRINT_SERVICE1 && -f $OCTOPRINT_SERVICE2 ]]; then
    status_msg "OctoPrint Service is disabled! Enabling now ..."
    sudo systemctl enable octoprint -q && sudo systemctl start octoprint
  fi
}

disable_octoprint_service(){
  if [[ -f $OCTOPRINT_SERVICE1 && -f $OCTOPRINT_SERVICE2 ]]; then
    status_msg "OctoPrint Service is enabled! Disabling now ..."
    sudo systemctl stop octoprint && sudo systemctl disable octoprint -q
  fi
}

toggle_octoprint_service(){
  if [[ -f $OCTOPRINT_SERVICE1 && -f $OCTOPRINT_SERVICE2 ]]; then
    if systemctl is-enabled octoprint.service -q; then
      disable_octoprint_service
      sleep 2
      CONFIRM_MSG=" OctoPrint Service is now >>> DISABLED <<< !"
    else
      enable_octoprint_service
      sleep 2
      CONFIRM_MSG=" OctoPrint Service is now >>> ENABLED <<< !"
    fi
  else
    ERROR_MSG=" You cannot activate a service that does not exist!"
  fi
}

read_octoprint_service_status(){
  if ! systemctl is-enabled octoprint.service -q &>/dev/null; then
    OPRINT_SERVICE_STATUS="${green}[Enable]${default} OctoPrint Service                        "
  else
    OPRINT_SERVICE_STATUS="${red}[Disable]${default} OctoPrint Service                       "
  fi
}

create_reverse_proxy(){
  #check for dependencies
  dep=(nginx)
  dependency_check
  #execute operations
  status_msg "Creating Nginx configuration for $1 ..."
  cat ${HOME}/kiauh/resources/$1_nginx.cfg > ${HOME}/kiauh/resources/$1
  sudo mv ${HOME}/kiauh/resources/$1 /etc/nginx/sites-available/$1
  #ONLY FOR MAINSAIL: replace username if not "pi"
    if [ "$1" = "mainsail" ]; then
      sudo sed -i "/root/s/pi/${USER}/" /etc/nginx/sites-available/mainsail
    fi
  ok_msg "Nginx configuration for $1 was set!"
  #remove default config
  if [ -e /etc/nginx/sites-enabled/default ]; then
    sudo rm /etc/nginx/sites-enabled/default
  fi
  #create symlink for own configs
  if [ ! -e /etc/nginx/sites-enabled/$1 ]; then
    sudo ln -s /etc/nginx/sites-available/$1 /etc/nginx/sites-enabled/
  fi
  restart_nginx
}

create_custom_hostname(){
  echo
  top_border
  echo -e "|  You can change the hostname of this machine to use   |"
  echo -e "|  that name to open the Interface in your browser.     |"
  echo -e "|                                                       |"
  echo -e "|  Example: If you set the hostname to 'my-printer'     |"
  echo -e "|           you can open Mainsail/Octoprint by          |"
  echo -e "|           browsing to: http://my-printer.local        |"
  bottom_border
  while true; do
    echo -e "${cyan}"
    read -p "###### Do you want to change the hostname? (Y/n): " yn
    echo -e "${default}"
    case "$yn" in
      Y|y|Yes|yes|"") set_hostname; break;;
      N|n|No|no) break;;
    esac
  done
}

set_hostname(){
  #check for dependencies
  dep=(avahi-daemon)
  dependency_check
  #execute operations
  #get current hostname and write to variable
  HOSTNAME=$(hostname)
  #create host file if missing or create backup of existing one with current date&time
  if [ -f /etc/hosts ]; then
    status_msg "Creating backup of hosts file ..."
    get_date
    sudo cp /etc/hosts /etc/hosts."$current_date".bak
    ok_msg "Backup done!"
    ok_msg "File:'/etc/hosts."$current_date".bak'"
  else
    sudo touch /etc/hosts
  fi
  echo
  top_border
  echo -e "|  ${green}Allowed characters: a-z, 0-9 and single '-'${default}          |"
  echo -e "|  ${red}No special characters allowed!${default}                       |"
  echo -e "|  ${red}No leading or trailing '-' allowed!${default}                  |"
  bottom_border
  while true; do
    echo -e "${cyan}"
    read -p "###### Please set the new hostname: " NEW_HOSTNAME
    echo -e "${default}"
    if [[ $NEW_HOSTNAME =~ ^[^\-]+([0-9a-z]\-{0,1})+[^\-]+$ ]]; then
      ok_msg "'$NEW_HOSTNAME' is a valid hostname!"
      #set hostname in /etc/hostname
      status_msg "Setting hostname to '$NEW_HOSTNAME' ..."
      status_msg "Please wait ..."
      sudo hostnamectl set-hostname $NEW_HOSTNAME
      #write new hostname to /etc/hosts
      status_msg "Writing new hostname to /etc/hosts ..."
      if cat /etc/hosts | grep "###set by kiauh" &>/dev/null; then
        sudo sed -i "/###set by kiauh/s/\<$HOSTNAME\>/$NEW_HOSTNAME/" /etc/hosts
      else
        echo "127.0.0.1     $NEW_HOSTNAME ###set by kiauh" | sudo tee -a /etc/hosts &>/dev/null
      fi
      ok_msg "New hostname successfully configured!"
      ok_msg "Remember to reboot your machine for the changes to take effect!"
      break
    else
      warn_msg "'$NEW_HOSTNAME' is not a valid hostname!"
    fi
  done
}

remove_branding(){
  echo
  top_border
  echo -e "|  This action will remove the Voron brandings from     |"
  echo -e "|  your Mainsail installation. You have to perform      |"
  echo -e "|  this action again, everytime you updated Mainsail.   |"
  bottom_border
  while true; do
    echo -e "${cyan}"
    read -p "###### Do you want to continue? (Y/n): " yn
    echo -e "${default}"
    case "$yn" in
      Y|y|Yes|yes|"")
        cd $MAINSAIL_DIR/css
        FILE=$(find -name "app.*.css" | cut -d"/" -f2)
        status_msg "Patching file '$FILE' ..."
        cp -n $KLIPPER_DIR/docs/img/klipper-logo-small.png $MAINSAIL_DIR/img/
        #write extra lines to app.css
        echo >> $FILE
        cat < ${HOME}/kiauh/resources/app.css >> $FILE
        ok_msg "File '$FILE' patched!"
        status_msg "Setting new Favicon ..."
        #backup old favicon
        cp -n $MAINSAIL_DIR/favicon.ico $MAINSAIL_DIR/voron_favicon.ico
        cp ${HOME}/kiauh/resources/favicon.ico $MAINSAIL_DIR/favicon.ico
        ok_msg "Icon set!"
        echo
        ok_msg "Brandings removed!"
        ok_msg "Clear browser cache and reload Mainsail (F5)!"
        echo
        break;;
      N|n|No|no) break;;
    esac
  done
}