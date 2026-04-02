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
In the extreme heat of the Arabian Gulf, nuclear power plant efficiency can drop significantly due to high seawater temperatures. This project introduces an **AI-Powered Digital Twin** for a **250 MWt NuScale SMR**. By utilizing **Genetic Algorithms (GA)**, the system dynamically balances the parasitic load of cooling pumps against turbine backpressure to maximize **Net Plant Power**.

---

## 🖥️ The SCADA Dashboard (New Feature)
The project now includes a professional, industrial-grade **Control Room Dashboard** (`PWR_Dashboard_exported.m`). 

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
* **`PWR_Dashboard_exported.m`:** The standalone SCADA-style application.
* **`/Assets`:** Contains the required visual resources, icons, and safety-informed indicators.

---

## 🛡️ Safety & Engineering Constraints
The AI is strictly bounded by nuclear safety regulations:
* **Vacuum Integrity:** Prevents Condenser pressure from exceeding **0.10 bar**.
* **Thermal Regulation:** Limits cooling water discharge temperature ($\Delta T$) to protect marine ecosystems.
* **Stall Prevention:** Ensures a minimum pump speed of 50% for operational stability.

---

## 🚀 Getting Started

### Prerequisites
* **MATLAB R2025b** or later.
* **Global Optimization Toolbox** (for the GA Engine).
* **XSteam Library** (Included in the root folder).

### Installation
1.  Clone the repository:
    ```bash
    git clone [https://github.com/YourUsername/SMR-AI-Optimization.git](https://github.com/YourUsername/SMR-AI-Optimization.git)
    ```
2.  Maintain the folder structure: Ensure the `Assets` folder is in the same directory as the `.m` files.
3.  Launch the Dashboard:
    ```matlab
    >> PWR_Dashboard_exported
    ```

---

## 👥 Project Team
* **Ahmed Saeed Alghamdi** - *Nuclear Engineering Lead*
* **Faisal Saeed Bahadi** - *Thermodynamics Specialist*
* **Ahmed Saud Alsalahi** - *Systems Integration*

**Supervised By:**
**Dr. Anas Alwafi**
*Department of Nuclear Engineering, King Abdulaziz University (KAU)*

---
<div align="center">
  <p>Copyright © 2026 | King Abdulaziz University | All Rights Reserved</p>
</div>
