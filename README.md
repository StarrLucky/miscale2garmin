# Export 2 to Garmin Connect

## 1. Introduction
- This project is based on following projects:
  - https://github.com/cyberjunky/python-garminconnect;
  - https://github.com/wiecosystem/Bluetooth;
  - https://github.com/userx14/omblepy;
  - https://github.com/lolouk44/xiaomi_mi_scale;
  - https://github.com/dorssel/usbipd-win;
  - https://github.com/rando-calrissian/esp32_xiaomi_mi_2_hass.

### 1.1. Miscale module:
- Allows fully automatic synchronization of Mi Body Composition Scale 2 (tested on XMTZC05HM) directly to Garmin Connect, with following parameters:
  - Date and Time;
  - Weight (**_NOTE:_ kg units only**);
  - BMI (Body Mass Index);
  - Body Fat;
  - Skeletal Muscle Mass;
  - Bone Mass;
  - Body Water;
  - Physique Rating;
  - Visceral Fat;
  - Metabolic Age.
- Miscale_backup.csv file also contains other calculated parameters (can be imported e.g. for analysis into Excel):
  - BMR (Basal Metabolic Rate);
  - LBM (Lean Body Mass);
  - Ideal Weight;
  - Fat Mass To Ideal;
  - Protein.
- Supports multiple users with individual weights ranges, we can link multiple accounts with Garmin Connect.

### 1.2. Omron module: 
- Allows fully automatic synchronization of Omron blood pressure (tested on M4/HEM-7155T and M7/HEM-7322T Intelli IT) directly to Garmin Connect, with following parameters:
  - Date and Time;
  - DIA (Diastolic Blood Pressure);
  - SYS (Systolic Blood Pressure);
  - BPM (Beats Per Minute).
- Omron_backup.csv file also contains other parameters (can be imported e.g. for analysis into Excel):
  - MOV (Movement Detection);
  - IHB (Irregular Heart Beat).
-  Supports 2 users from Omron device, we can connect 2 accounts with Garmin Connect.

### 1.3. User module:
- Enables configuration of all parameters related to integration Miscale and Omron;
- Provides export Oauth1 and Oauth2 tokens of your account from Garmin Connect (MFA/2FA support).

## 2. How does this work
- Miscale and Omron modules can be activated individually or run together:
```
$ /home/robert/export2garmin-master/import_data.sh
Export 2 Garmin Connect v1.4 (import_data.sh)

18.07.2024-16:56:01 MISCALE * Module is on
18.07.2024-16:56:01 MISCALE * miscale_backup.csv file exists, check if temp.log exists
18.07.2024-16:56:01 MISCALE * temp.log file exists, checking for new data
18.07.2024-16:56:01 MISCALE * Importing data from a BLE scanner
18.07.2024-16:56:06 MISCALE * Saving import 1721314589 to miscale_backup.csv file
18.07.2024-16:56:07 MISCALE * Calculating data from import 1721314589, upload to Garmin Connect
18.07.2024-16:56:07 MISCALE * Data upload to Garmin Connect is complete
18.07.2024-16:56:07 MISCALE * Saving calculated data from import 1721314589 to miscale_backup.csv file
18.07.2024-16:56:07 OMRON * Module is on
18.07.2024-16:56:07 OMRON * omron_backup.csv file exists, check if temp.log exists
18.07.2024-16:56:07 OMRON * temp.log file exists, checking for new data
18.07.2024-16:56:07 OMRON * Importing data from a BLE scanner
18.07.2024-16:56:39 OMRON * Prepare data for omron_backup.csv file
18.07.2024-16:56:40 OMRON * Data from import 1721314552 upload to Garmin Connect
18.07.2024-16:56:40 OMRON * Data upload to Garmin Connect is complete
18.07.2024-16:56:40 OMRON * Saving calculated data from import 1721314552 to omron_backup.csv file
```
- Synchronization diagram from Export 2 to Garmin Connect:

![alt text](https://github.com/RobertWojtowicz/export2garmin/blob/master/manuals/workflow.png)

### 2.1. Miscale module | BLE VERSION
- After weighing, Mi Body Composition Scale 2 is active for 15 minutes on bluetooth transmission;
- USB Bluetooth adapter or internal module scans BLE devices for 10 seconds to acquire data from scale;
- Body weight and impedance data on server are appropriately processed by scripts;
- Processed data are sent to Garmin Connect;
- Raw and calculated data from scale is backed up on server in miscale_backup.csv file.

**Select your platform and go to instructions:**
- [Debian 12 | Raspberry Pi OS](https://github.com/RobertWojtowicz/export2garmin/blob/master/manuals/Miscale_BLE.md);
- [Windows 11](https://github.com/RobertWojtowicz/export2garmin/blob/master/manuals/all_BLE_win.md).

### 2.2. Miscale module | ESP32 VERSION
- After weighing, Mi Body Composition Scale 2 is active for 15 minutes on bluetooth transmission;
- ESP32 module operates in a deep sleep and wakes up every 7 minutes, scans BLE devices for 10 seconds to acquire data from scale, process can be started immediately via reset button;
- ESP32 module sends acquired data via MQTT protocol to MQTT broker installed on server;
- Body weight and impedance data on server are appropriately processed by scripts;
- Processed data are sent to Garmin Connect;
- Raw and calculated data from scale is backed up on server in miscale_backup.csv file.

**Select your platform and go to instructions:**
- [Debian 12 | Raspberry Pi OS](https://github.com/RobertWojtowicz/export2garmin/blob/master/manuals/Miscale_ESP32.md);
- [Windows 11](https://github.com/RobertWojtowicz/export2garmin/blob/master/manuals/Miscale_ESP32_win.md).

### 2.3. Omron module | BLE VERSION
- After measuring blood pressure, Omron allows you to download measurement data once;
- USB bluetooth adapter or internal module scans BLE devices for 10 seconds to acquire data from blood pressure device (downloading data can take about 1 minute);
- Pressure measurement data are appropriately processed by scripts on server;
- Processed data are sent to Garmin Connect;
- Raw and calculated data from device is backed up on server in omron_backup.csv file.

**Select your platform and go to instructions:**
- [Debian 12 | Raspberry Pi OS](https://github.com/RobertWojtowicz/export2garmin/blob/master/manuals/Omron_BLE.md);
- [Windows 11](https://github.com/RobertWojtowicz/export2garmin/blob/master/manuals/all_BLE_win.md).

## If you like my work, you can buy me a coffee
<a href="https://www.buymeacoffee.com/RobertWojtowicz" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="41" width="174"></a>