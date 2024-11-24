import re
import os
import subprocess

# Paths to the re-uploaded files
tmp_out1_path = './logs1/tmp.out1' 

benchmark_golden_dict = {
    'bfs': "golden_bfs.txt",
    'backprop': 'golden_backprop.txt',
    '2mm': 'golden_2mm.txt',
    '3mm': 'golden_3mm.txt',
    'sradv2': 'golden_srad2.txt',
    '2dconv': 'golden_2dconv.txt',
    'gaussian': 'golden_gaussian.txt',
    'nw': 'golden_nw.txt',
    'kmeans': 'golden_kmeans.txt',
    'lud': 'golden_lud.txt',
    'pathfinder': 'golden_pathfinder.txt',
    'hotspot': 'golden_hotspot.txt'
}

 
run_benchmark_CUDA_UUT = {
    'bfs': "./bfs graph4096.txt",
    '2dconv': "./polybench-2DConvolution",
    '2mm': "./polybench-2mm",
    'backprop': "./backprop-rodinia-3.1 8192",
    '3mm': "./polybench-3mm",
    'gaussian': "./gaussian -f matrix16.txt",
    'hotspot': "./hotspot 128 2 2 temp_512 power_512 result.txt",
    'kmeans': "./kmeans-rodinia-3.1 -o -i 100",
    'lud': "./lud -i 64.dat -v",
    'nw': "./nw 112 8",
    'pathfinder': "./pathfinder 1000 100 20",
    'sradv2': "./srad2 128 128 0 127 0 127 0.5 2"
}

run_benchmark_sh_all_path = {
    './run_bfs2.sh',
    './run_2dconv.sh',
    './run_2mm.sh',
    './run_backprop.sh',
    './run_3mm.sh',
    './run_gaussian.sh',
    './run_hotspot.sh',
    './run_kmeans.sh',
    './run_lud.sh',
    './run_nw.sh',
    './run_pathfinder.sh',
    './run_sradv2.sh'

}

for run_benchmark_sh_path in run_benchmark_sh_all_path:
    # Extract benchmark name from the script path
    benchmark = re.search(r'run_(\w+)\.sh', run_benchmark_sh_path).group(1)
    run_benchmark_sh_path = './run_kmeans.sh'
    with open(run_benchmark_sh_path, 'r') as run_benchmark_file:
        run_benchmark_content = run_benchmark_file.read()


        run_benchmark_content = re.sub(r'^RUNS=\s*\d+\s*(#.*)?$', 'RUNS=1000', run_benchmark_content, flags=re.MULTILINE)
        run_benchmark_content = re.sub(r'^L2_SIZE_BITS=\s*\d+\s*(#.*)?$', 'L2_SIZE_BITS=53133312', run_benchmark_content, flags=re.MULTILINE)
        run_benchmark_content = re.sub(r'^profile=\s*\d+\s*(#.*)?$', 'profile=1', run_benchmark_content, flags=re.MULTILINE)
        run_benchmark_content = re.sub(r'^DELETE_LOGS=\s*1\s*(#.*)?$', 'DELETE_LOGS=0', run_benchmark_content, flags=re.MULTILINE)

    cuda_out=run_benchmark_CUDA_UUT[benchmark]
    run_benchmark_content = re.sub(
    r'^CUDA_UUT=.*$', 
    f'CUDA_UUT="{cuda_out}"', 
    run_benchmark_content, 
    flags=re.MULTILINE
)
    gold_file = benchmark_golden_dict[benchmark]
    run_benchmark_content = re.sub(
    r'--file1 \./golden_[\w\-]+\.txt', 
    f'--file1 ./{gold_file}', 
    run_benchmark_content
)

    profile_script_path = f'run_{benchmark}_profile.sh'
    with open(profile_script_path, 'w') as profile_script_file:
        profile_script_file.write(run_benchmark_content)

    # Make the script executable
    os.chmod(profile_script_path, 0o755)


    try:
        result = subprocess.run([f'./{profile_script_path}'], shell=True, check=True, text=True, capture_output=True)
        print(f"Output for {benchmark}:", result.stdout)
        if result.stderr:
            print(f"Error for {benchmark}:", result.stderr)
    except subprocess.CalledProcessError as e:
        print(f"An error occurred while running {profile_script_path}: {e}")
        print("Error output:", e.stderr) 
 


    with open(tmp_out1_path, 'r') as tmp_file:
        tmp_out1_content = tmp_file.read()

 
    # Last cycle in tmp.out1 for updating cycle information
    last_cycle_pattern = r'gpu_tot_sim_cycle\s*=\s*(\d+)'
    last_cycle_matches = re.findall(last_cycle_pattern, tmp_out1_content)
    last_cycle = max(map(int, last_cycle_matches)) if last_cycle_matches else 111 

    run_benchmark_content = re.sub(r'CYCLES=\d+', f'CYCLES={last_cycle}', run_benchmark_content, flags=re.MULTILINE)
    
    print("benchmark:{},cycle{}  ",benchmark,last_cycle)
    with open(profile_script_path, 'w') as profile_script_file:
        profile_script_file.write(run_benchmark_content)


    os.chmod(profile_script_path, 0o755)

    run_benchmark_content = re.sub(r'^profile=\s*1\s*(#.*)?$', 'profile=0', run_benchmark_content, flags=re.MULTILINE)
    
    with open(tmp_out1_path, 'r') as tmp_file:
        tmp_out1_content = tmp_file.read()

    # Define the output shell script template for each kernel, based on run_bfs2.sh
    def generate_kernel_script(template_content, kernel_name, shaders, max_regs, cycles_file, cycles, smem_size_bits): 
        """
        Generate the content for each kernel's run_*.sh file by replacing placeholders in the template content.
        """
        script_content = template_content
        script_content = re.sub(r'CYCLES=\d+', f'CYCLES={cycles}', script_content, flags=re.MULTILINE)
        script_content = re.sub(r'CYCLES_FILE=.+', f'CYCLES_FILE=./{cycles_file}', script_content, flags=re.MULTILINE)
        script_content = re.sub(r'MAX_REGISTERS_USED=\d+', f'MAX_REGISTERS_USED={max_regs}', script_content, flags=re.MULTILINE)
        script_content = re.sub(r'SHADER_USED="[^"]+"', f'SHADER_USED="{shaders}"', script_content, flags=re.MULTILINE)
        script_content = re.sub(r'SMEM_SIZE_BITS=\d+', f'SMEM_SIZE_BITS={smem_size_bits}', script_content, flags=re.MULTILINE)
        script_content = re.sub(r'^BENCHMARK=\s*\d+\s*(#.*)?$', f'BENCHMARK={kernel_name}', script_content, flags=re.MULTILINE)


        

        return script_content

    kernel_info_pattern = r'Kernel\s*=\s*(\S+),\s*max\s*active\s*regs\s*=\s*(\d+)'
    kernel_info_matches = re.findall(kernel_info_pattern, tmp_out1_content)

    # Pattern to extract used shaders
    shaders_pattern = r'Kernel\s*=\s*(\S+)\s*used\s*shaders:\s*([\d\s]+)'
    shaders_matches = re.findall(shaders_pattern, tmp_out1_content)

    ptx_pattern = r"GPGPU-Sim PTX: Kernel '(\S+)' : regs=(\d+), lmem=\d+, smem=(\d+), cmem=(\d+)"
    ptx_matches = re.findall(ptx_pattern, tmp_out1_content)

    # Create a dictionary for kernel data
    kernel_data = {} 

    for name, regs in kernel_info_matches:
        kernel_data[name] = {'max_regs': int(regs), 'shaders': '', 'smem_size_bits': 1111}  # Default SMEM_SIZE_BITS = 10

    # Populate shaders information
    for name, shaders in shaders_matches:
        if name in kernel_data:
            kernel_data[name]['shaders'] = shaders.strip()

    for name, regs, smem, cmem in ptx_matches:
        if name in kernel_data:
            kernel_data[name]['smem_size_bits'] = int(smem)


    # Pattern to extract cycle information
    cycle_pattern = r'Kernel\s*=\s*\d+\s*with\s*name\s*=\s*(\S+),\s*started\s*on\s*cycle\s*=\s*(\d+)\s*and\s*finished\s*on\s*cycle\s*=\s*(\d+)'
    cycle_matches = re.findall(cycle_pattern, tmp_out1_content)

    # Last cycle in tmp.out1 for updating cycle information
    last_cycle_pattern = r'gpu_tot_sim_cycle\s*=\s*(\d+)'
    last_cycle_matches = re.findall(last_cycle_pattern, tmp_out1_content)
    last_cycle = max(map(int, last_cycle_matches)) if last_cycle_matches else 48020  # Default to 48020 if not found

    # Organize cycle data by kernel name
    cycles_data = {name: [] for name in kernel_data.keys()}
    for name, start, end in cycle_matches:
        if name in cycles_data:
            cycles_data[name].append((int(start), int(end)))

    # Generate script files and
            
    output_scripts = {}
    output_cycle_files = {}

    for kernel_name, details in kernel_data.items():
        max_regs = details['max_regs']
        shaders = details['shaders']
        smem_size_bits = details['smem_size_bits']
        cycles_file = f"cycle_{kernel_name}.txt"

        # Generate cycle file content
        cycle_content = "\n".join([str(seq) for start, end in cycles_data[kernel_name] for seq in range(start, end + 1)])

        # Generate shell script content
        run_script_name = f"run_{kernel_name}.sh"
        script_content = generate_kernel_script(run_benchmark_content, kernel_name, shaders, max_regs, cycles_file, last_cycle, smem_size_bits)

        output_scripts[run_script_name] = script_content
        output_cycle_files[cycles_file] = cycle_content

    # Define the directory for saving generated content.
    output_dir   =    f'./run_{benchmark}_scripts' #'./run_{benchmark}_scripts'

    os.makedirs(output_dir, exist_ok=True)

    # Write each generated script to a file
    for script_name, script_content in output_scripts.items():
        script_path = os.path.join(output_dir, script_name)
        with open(script_path, 'w') as script_file:
            script_file.write(script_content)
        os.chmod(script_path, 0o755)  # Make the script executable

    # Write each generated cycle file to a file
    for cycle_file_name, cycle_content in output_cycle_files.items():
        cycle_file_path = os.path.join(output_dir, cycle_file_name)
        with open(cycle_file_path, 'w') as cycle_file:
            cycle_file.write(cycle_content)




