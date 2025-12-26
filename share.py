import json
import argparse
import asyncio
import telegram

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from typing import Tuple

def get_data() -> Tuple[str, dict, dict]:
    """
    Get and process data obtained by acquire.sh.
    """    
    num_cores = np.loadtxt("./data/numCores.txt") # Number of CPU cores
    cpu_load = np.loadtxt("./data/cpuLoad.txt") # Average CPU load (1 minute)
    cpu_temp = np.loadtxt("./data/cpuTemp.txt") # Temperature (mC)
    mem_free = np.loadtxt("./data/memFree.txt") # Free RAM (kB)
    mem_total = np.loadtxt("./data/memTotal.txt") # Total RAM (kB)
    distro_name = np.loadtxt("./data/distroName.txt", dtype=str) # Total RAM (kB)
    
    history, avg = {}, {}
    history["ram"] = (1-mem_free/mem_total)*100
    history["cpu"] = cpu_load/num_cores*100
    history["temp"] = cpu_temp/1000
    history["size"] = cpu_load.size
    
    for key in ["ram", "cpu", "temp"]:
        avg[key] = np.mean(history[key]) # Average
    
    return distro_name, history, avg
    
def plot_data(data: dict, num_bins: int = 40) -> str:
    """
    Plot data
    """
        
    def apply_cmap(cm, patches) -> None:
        """
        Apply colormap.
        """
        norm = mcolors.Normalize(vmin = 0, vmax = len(patches) - 1)
        for i, patch in enumerate(patches):
            patch.set_facecolor(cm(norm(i)))
    
    plt.rcParams.update({'font.size': 16})
    fig, axs = plt.subplots(2, 2, figsize = (10, 10), dpi = 400)
    cmap = plt.get_cmap('coolwarm')
    
    _, _, patches = axs[0,0].hist(data['cpu'], bins = num_bins, density = True, range = (0,100))
    apply_cmap(cmap, patches)
    axs[0,0].set_xlabel('Load [%]')
    axs[0,0].set_title('CPU')

    _, _, patches = axs[0,1].hist(data['ram'], bins = num_bins, density = True, range = (0,100))
    apply_cmap(cmap, patches)
    axs[0,1].set_xlabel('Usage [%]')
    axs[0,1].set_title('RAM')
    
    _, _, patches = axs[1,1].hist(data['temp'], bins = num_bins, density = True)
    apply_cmap(cmap, patches)
    axs[1,1].set_xlabel('Temperature [°C]')
    axs[1,1].set_title('Thermal')
    
    fig.tight_layout()
    filepath = "./plot.png"
    plt.savefig(filepath) # Save figure
    return filepath
    
async def main() -> None:
    """
    Deliver message through BotFather API. Assume str:chatID and
    str:token are passed through --config secrets.json during the
    script call.
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    args = parser.parse_args()

    with open(args.config, "r", encoding="utf-8") as file:
        data = json.load(file)
    
    distro, history, avg = get_data() # Data
    path = plot_data(history) # Plots
    text =\
    f"{distro}\n" +\
    f"CPU: {avg['cpu']:.1f}%\n" +\
    f"RAM: {avg['ram']:.1f}%\n" +\
    f"Thermal: {avg['temp']:.1f}°C"
    
    bot = telegram.Bot(data["token"]) # Call API
    async with bot:
        await bot.sendPhoto(data["chatID"], path)
        await bot.sendMessage(data["chatID"], text)

if __name__ == '__main__':
    asyncio.run(main())
