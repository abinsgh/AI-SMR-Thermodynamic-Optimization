<div align="center">
  <h1>🧠 AI-Driven SMR Rankine Cycle Optimization</h1>
  <h3>Genetic Algorithm Optimization for NuScale SMR Cooling Systems</h3>
</div>

<p align="center">
  <img src="https://img.shields.io/badge/Language-MATLAB-0076A8?style=for-the-badge&logo=mathworks&logoColor=white" />
  <img src="https://img.shields.io/badge/Algorithm-Genetic_Algorithm_(GA)-38B2AC?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Domain-Thermodynamics_%26_Systems_Engineering-D14836?style=for-the-badge" />
</p>

---

## 📝 Project Overview

This project develops a dynamic thermodynamic simulation and an AI-driven optimization model for the secondary loop of a Small Modular Reactor (SMR), specifically conceptually modeled around NuScale operational parameters. 

The primary objective is to maximize the **Net Power Output** of the plant by intelligently adjusting auxiliary loads (Pump Speed) and Moisture Separator Reheater (MSR) valve positioning based on varying environmental conditions (e.g., Seasonal Seawater Temperature).

## ⚙️ Core Architecture

The repository consists of two main MATLAB scripts:

1. **`Plant_Physics.m` (The Digital Twin):** A robust physical model of the plant's thermodynamic cycle. It calculates the exact intersections between pump curves and system resistance, models dynamic condenser heat transfer (LMTD), and evaluates high-pressure and low-pressure turbine outputs utilizing the `XSteam` water properties library.
2. **`Run_Optimization.m` (The AI Engine):** Deploys a **Genetic Algorithm (GA)** to explore the solution space. It strategically trades off pump power consumption against turbine efficiency drops due to higher condenser backpressure.

## 🧠 Smart Cost Function & Constraints

Instead of simple mathematical minimization, the GA utilizes a physics-informed cost function designed to prevent operational hazards. The algorithm minimizes the negative of the Net Power `(-W_Net)` while strictly enforcing mechanical limits via severe mathematical penalties:

* **Stall Protection Penalty:** Prevents the pump speed from dropping below safe operational limits (< 50%).
* **Turbine Trip Penalty:** Heavily penalizes the algorithm if condenser backpressure exceeds the critical threshold (0.10 bar).
* **Environmental Penalty:** Limits the cooling water discharge temperature difference ($\Delta T$) to comply with ecological regulations.

## 📊 Results & Impact

By shifting from a traditional "100% fixed pump speed" operational baseline to an AI-optimized variable speed approach, the system demonstrates the ability to dynamically save **Auxiliary Power (kW to MW scale)** during favorable seasonal conditions, directly increasing the overall plant net efficiency.

---

### 🚀 How to Run
1. Ensure you have MATLAB installed with the **Global Optimization Toolbox**.
2. Download the [XSteam library](https://www.mathworks.com/matlabcentral/fileexchange/9817-x-steam-thermodynamic-properties-of-water-and-steam) and place it in the exact same directory.
3. Run `Run_Optimization.m`.
