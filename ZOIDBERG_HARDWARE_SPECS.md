# 🖥️ Zoidberg Mac Hardware Specifications

## 📋 System Overview

**Device**: MacBook Pro  
**Model Identifier**: Mac16,7  

---

## 🔧 Core Hardware

### 💻 Processor (CPU)
- **Chip**: Apple M4 Pro
- **Architecture**: ARM-based System on Chip (SoC)
- **Total Cores**: 14 cores
  - **Performance Cores**: 10
  - **Efficiency Cores**: 4
- **Brand String**: Apple M4 Pro

### 🎮 Graphics (GPU)
- **GPU**: Apple M4 Pro (Integrated)
- **GPU Cores**: 20 cores
- **Metal Support**: Metal 3
- **Vendor**: Apple (0x106b)
- **Bus**: Built-In

### 🧠 Memory (RAM)
- **Total Capacity**: 48 GB
- **Type**: LPDDR5
- **Manufacturer**: Hynix
- **Architecture**: Unified Memory Architecture (shared between CPU and GPU)

---

## 💾 Storage

### Primary Storage Device
- **Device Name**: APPLE SSD AP1024Z
- **Total Capacity**: ~1 TB (994.66 GB usable)
- **Technology**: SSD (Solid State Drive)
- **Protocol**: Apple Fabric
- **Form Factor**: Internal
- **S.M.A.R.T. Status**: Verified
- **File System**: APFS (Apple File System)

---

## 🖥️ Display

### Built-in Display
- **Type**: Built-in Liquid Retina XDR Display
- **Resolution**: 3456 x 2234 (Retina)
- **Technology**: Mini-LED with XDR (Extreme Dynamic Range)

---

## 🔋 Power & Battery

### Battery Specifications
- **Model**: bq40z651
- **Cycle Count**: 8 (virtually new)
- **Current Condition**: Normal
- **Maximum Capacity**: 100%
- **Current Charge**: 100% (Fully Charged)

### Power Adapter
- **Type**: AC Charger
- **Wattage**: 85W
- **Status**: Connected

### Power Management
- **Sleep Timers (AC Power)**:
  - System Sleep: 1 minute
  - Display Sleep: 10 minutes
  - Disk Sleep: 10 minutes
- **Sleep Timers (Battery Power)**:
  - System Sleep: 1 minute
  - Display Sleep: 2 minutes
  - Disk Sleep: 10 minutes

---

## 🔌 Connectivity

### USB Interfaces
- **USB 3.1 Buses**: 3 controllers (AppleT8132USBXHCI)
- **USB 3.0 Bus**: 1 controller (AppleUSBXHCIFL1100)
- **Additional USB 3.1 Bus**: 1 controller (AppleUSBXHCITR)

### External Devices Connected
- **USB3.2 Hub** (GenesysLogic)
  - Speed: Up to 5 Gb/s
  - Available Current: 900 mA
- **Texas Instruments Hubs** (Multiple)
  - Speed: Up to 5 Gb/s
  - Available Current: 900 mA each

---

## 🌐 Network Controllers

### 📡 Wireless (WiFi)
- **Chipset**: Wi-Fi (0x14E4, 0x4388) - Broadcom
- **Standards Supported**: 802.11 a/b/g/n/ac/ax (WiFi 6E)
- **Frequency Bands**: 
  - **2.4 GHz**: Channels 1-13
  - **5 GHz**: Channels 36-165 (DFS channels supported)
  - **6 GHz**: Channels 1-93 (WiFi 6E)
- **Country Code**: DE (Germany/ETSI)
- **Features**:
  - Wake On Wireless: Supported
  - AirDrop: Supported
  - Auto Unlock: Supported
  - Current Connection: 802.11n @ 144 Mbps (Channel 6, 2.4GHz)

### 🔗 Bluetooth
- **Controller**: BCM_4388C2 (Broadcom)
- **Transport**: PCIe
- **Supported Services**: HFP, AVRCP, A2DP, HID, Braille, LEA, AACP, GATT, SerialPort

### 🔌 Ethernet Controllers

#### Built-in Ethernet Adapters
1. **Ethernet Adapter (en4)**
   - **Type**: Hardware Ethernet
   - **Status**: Inactive

2. **Ethernet Adapter (en5)**
   - **Type**: Hardware Ethernet
   - **Status**: Inactive

3. **Ethernet Adapter (en6)**
   - **Type**: Hardware Ethernet
   - **Status**: Inactive

#### External Ethernet Adapters
1. **USB 10/100/1000 LAN (en7)**
   - **Interface**: USB-based Gigabit Ethernet
   - **Status**: DHCP configured

2. **Thunderbolt Ethernet Slot 2 (en8)**
   - **Interface**: Thunderbolt-based Ethernet
   - **Status**: Inactive

3. **USB 10/100/1G/2.5G LAN (en9)**
   - **Interface**: USB-based 2.5 Gigabit Ethernet
   - **Status**: DHCP configured

#### Virtual Network Interfaces
- **Thunderbolt Bridge (bridge0)**: Bridges en1, en2, en3 interfaces
- **Apple Wireless Direct Link (awdl0)**: Peer-to-peer networking
- **Low Latency WLAN (llw0)**: Apple-specific wireless interface

### 🛡️ VPN & Security
- **Tailscale VPN**: Integrated mesh VPN solution
  - **Type**: io.tailscale.ipn.macos
  - **Configuration**: Automatic IPv4/IPv6
  - **Status**: Active

### 🌍 Network Configuration
- **Primary Connection**: Wi-Fi (DHCP)
- **IPv6**: Dual-stack with automatic configuration
- **Network Services Priority**:
  1. Ethernet Adapters (en4-en6)
  2. USB Ethernet adapters
  3. Thunderbolt Ethernet
  4. Wi-Fi
  5. Tailscale VPN
