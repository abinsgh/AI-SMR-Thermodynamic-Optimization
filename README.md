<div align="center">
  <img src="https://img.shields.io/badge/NUCLEAR_ENGINEERING-KAU-green?style=for-the-badge" />
  <img src="https://img.shields.io/badge/AI_OPTIMIZATION-GENETIC_ALGORITHM-orange?style=for-the-badge" />
  <br>
  <h1>⚛️ NuScale SMR: Intelligent Control & Optimization</h1>
  <h3>AI-Driven Rankine Cycle Management for the VOYGR™ SMR Module</h3>
  
  <p align="center">
    <img src="https://img.shields.io/badge/MATLAB-R2025b-0076A8?style=flat-square&logo=mathworks&logoColor=white" />
    <img src="https://img.shields.io/badge/Optimization-GA_Toolbox-38B2AC?style=flat-square" />
    <img src="https://img.shields.io/badge/UI_Design-SCADA_Dashboard-D14836?style=flat-square" />
  </p>
</div>

---

## 📖 Project Vision
In the extreme heat of the Arabian Gulf, nuclear power plant efficiency can drop significantly due to high seawater temperatures. This project introduces an **AI-Powered Digital Twin** for a **250 MW NuScale SMR (Small Modular Reactor)**, utilizing advanced Genetic Algorithms to optimize the Rankine Cycle thermodynamics in real-time.

---

## 🖥️ The SCADA Dashboard (New Feature)
The project now includes a professional, industrial-grade **Control Room Dashboard** (`PWR_Dashboard.mlapp`). 

* **Real-time Interaction:** Use the high-precision slider to simulate seasonal sea temperature changes (10°C to 40°C).
* **Intelligent Gauges:** Monitor Condenser Vacuum, Pump Load, and Net Generation via native MATLAB gauges.
* **Safety Interlocks:** Visual "Safety Lamps" that trigger warnings if condenser pressure approaches the critical **0.10 bar** trip limit.
* **Comparative Analytics:** Direct side-by-side comparison between "Traditional Operation" and "AI-Optimized Operation".

---

## ⚙️ Repository Architecture

### 1. The Intelligence Core
* **`Plant_Physics.m`:** The thermodynamic engine. Models LMTD heat transfer, pump-system curve intersections, and turbine work using the `XSteam` library.
* **`Run_Optimization.m`:** The training script for the Genetic Algorithm to find optimal speed/valve positioning.

### 2. The Professional Interface
* **`PWR_Dashboard.mlapp`:** The modern MATLAB App Designer application (successor to the exported version).
* **`/Assets`:** Contains the required visual resources, icons, and safety-informed indicators.

### 3. Supporting Libraries
* **`XSteam/`:** Steam properties calculator library (essential for thermodynamic calculations).
* **Additional Helper Functions:** Various optimization and utility scripts.

---

## 🛡️ Safety & Engineering Constraints
The AI is strictly bounded by nuclear safety regulations:
* **Vacuum Integrity:** Prevents Condenser pressure from exceeding **0.10 bar**.
* **Thermal Regulation:** Limits cooling water discharge temperature (ΔT) to protect marine ecosystems.
* **Stall Prevention:** Ensures a minimum pump speed of 50% for operational stability.

---

## 🚀 Getting Started

### Prerequisites
* **MATLAB R2025b** or later.
* **Global Optimization Toolbox** (for the GA Engine).
* **XSteam Library** (Included in the repository).
* **MATLAB App Designer** (for running `.mlapp` files).

### 📁 Folder Structure & File Organization
```
AI-SMR-Thermodynamic-Optimization/
├── PWR_Dashboard.mlapp              # Main SCADA Dashboard Application
├── Plant_Physics.m                  # Thermodynamic calculations
├── Run_Optimization.m               # Genetic Algorithm training script
├── XSteam/                          # Steam properties library
├── Assets/                          # UI resources, icons, and gauges
│   ├── icons/
│   ├── gauges/
│   └── [other visual resources]
└── README.md
```

### ✅ Installation & Setup Guide

#### Step 1: Clone the Repository
```bash
git clone https://github.com/abinsgh/AI-SMR-Thermodynamic-Optimization.git
cd AI-SMR-Thermodynamic-Optimization
```

#### Step 2: Set MATLAB Path
It is **critical** that you add all project folders to MATLAB's search path so that all dependencies are correctly resolved.

**Method A: Using MATLAB GUI**
1. Open MATLAB
2. Click **Home** → **Set Path**
3. Click **Add Folder** and select your project root directory
4. Click **Add with Subfolders** to include `XSteam/` and `Assets/`
5. Click **Save** and then **Close**

**Method B: Using MATLAB Command Window**
```matlab
addpath(genpath('C:\Users\YourUsername\...\AI-SMR-Thermodynamic-Optimization'));
savepath;
```
*(Replace the path with your actual project directory)*

#### Step 3: Verify XSteam Installation
Test that the XSteam library is accessible:
```matlab
% Run this in the MATLAB Command Window
iapws_if97(3, 300, 0.0035);  % Should return steam properties without errors
```

#### Step 4: Launch the Dashboard Application
```matlab
PWR_Dashboard
```
This will open the interactive SCADA dashboard where you can:
- Adjust sea water temperature (10–40°C)
- View real-time plant performance metrics
- Compare AI-Optimized vs. Traditional operation modes
- Monitor safety constraints visually

#### Step 5: Run the Optimization Engine (Optional)
To train the Genetic Algorithm on new parameters:
```matlab
Run_Optimization
```
This will execute the GA and save optimized control parameters.

---

## 📊 How to Use the Dashboard

### 1. **Starting the Application**
   - Execute `PWR_Dashboard` in MATLAB
   - The dashboard will load with default operating conditions

### 2. **Adjusting Operating Conditions**
   - Use the **Sea Temperature Slider** to simulate seasonal variations
   - The plant automatically recalculates performance metrics

### 3. **Monitoring Safety Systems**
   - Red "Safety Lamps" indicate constraint violations
   - Green indicates nominal operation within all safety bounds

### 4. **Comparing Optimization Results**
   - Two parallel displays show:
     - **Left Panel:** Traditional fixed-parameter operation
     - **Right Panel:** AI-optimized dynamic control
   - Compare efficiency gains and constraint satisfaction

### 5. **Saving Results**
   - Dashboard automatically logs operational data
   - Export results for further analysis if needed

---

## 🔧 File Structure Details

### **PWR_Dashboard.mlapp**
- Modern MATLAB App Designer interface
- Real-time gauge displays
- Safety interlocks and visual alerts
- Interactive sliders for parameter tuning

### **Plant_Physics.m**
Core thermodynamic modeling:
- Condenser heat transfer (LMTD method)
- Pump system curve intersection
- Turbine expansion calculations
- XSteam integration for fluid properties

### **Run_Optimization.m**
Genetic Algorithm optimization:
- Initializes GA population
- Evaluates fitness (efficiency + safety)
- Generates Pareto-optimal solutions
- Saves best parameters for dashboard use

### **XSteam Library**
Open-source steam properties calculator:
- Calculates thermodynamic properties across operating ranges
- Essential for accurate plant modeling

---

## ⚠️ Important Notes

1. **MATLAB Path Configuration is Critical**
   - Failure to add the project folder to MATLAB path will cause "Undefined function" errors
   - Always use `addpath(genpath(...))` to include subdirectories

2. **XSteam Dependency**
   - Ensure the XSteam folder is in the MATLAB path
   - Test with `iapws_if97()` function to verify installation

3. **Assets Folder**
   - The `/Assets` folder must remain in the project root
   - Dashboard references these files for icons and gauge displays
   - Do not move or rename this folder

4. **MATLAB Compatibility**
   - Developed for MATLAB R2025b
   - May work on earlier versions, but not guaranteed
   - `.mlapp` files require MATLAB App Designer

---

## 📈 Performance Expectations

When running the dashboard with proper setup:
- **Dashboard Launch Time:** 2–5 seconds
- **Real-time Updates:** 60 FPS gauge refresh rate
- **Optimization Run Time:** 30–120 seconds (depends on GA population)
- **Memory Usage:** ~500 MB typical

---

## 👥 Project Team
* **Ahmed Saeed Alghamdi** - *Nuclear Engineering Lead*
* **Faisal Saeed Bahadi** - *Thermodynamics Specialist*
* **Ahmed Saud Alsalahi** - *Systems Integration*

**Supervised By:**
**Dr. Anas Alwafi**
*Department of Nuclear Engineering, King Abdulaziz University (KAU)*

---

## 📝 License & Citation
Copyright © 2026 | King Abdulaziz University | All Rights Reserved

For academic use, please cite this project in your research.

---

<div align="center">
  <p>🚀 <strong>Last Updated: April 2026</strong> | Ready for Production Use ✅</p>
</div>
