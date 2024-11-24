#!/bin/bash
 

benchmark='kmeans' #'bfs2'
run_scripts_dir="./run_${benchmark}_scripts"
script_path="${run_scripts_dir}/run__Z14invert_mappingPfS_ii.sh"
Cur_Benchmark="kmeans_2"


declare -A hardware_dict=(
    [0]="RF"
    [2]="shared_mem"
    [3]="L1D_cache"
    [6]="L2_cache"
    [7]="PC"
    [8]="opcode"
    [9]="mask"
    [10]="reg"
)

# Define corresponding directories
declare -A directories=(
    [0]="../result/RF"
    [2]="../result/shared_mem"
    [3]="../result/L1D_cache"
    [6]="../result/L2_cache"
    [7]="../result/PC"
    [8]="../result/opcode"
    [9]="../result/mask"
    [10]="../result/reg"
)

# Create result directories if not exist
for dir_path in "${directories[@]}"; do
    mkdir -p "$dir_path"
done

# Define the list of components to flip
components_to_flip_list=(2 0 3 6 7 8 9 10)

source setup_environment
rm *.csv


# Check if directory exists
if [ ! -d "$run_scripts_dir" ]; then
    echo "Notice: $run_scripts_dir not found, skipping benchmark $benchmark."
    exit 1  # Exit script if directory does not exist
fi

# Check if script file exists
if [ ! -f "$script_path" ]; then
    echo "No run_*.sh scripts found in $run_scripts_dir."
    exit 1
fi

# Extract kernel name
filename=$(basename "$script_path")
if [[ $filename =~ run_(.+)\.sh ]]; then
    kernel="${BASH_REMATCH[1]}"
    echo "Processing script: $script_path"
else
    echo "Filename $filename does not match pattern run_*.sh, skipping."
    exit 1
fi

# Read script content
script_content=$(cat "$script_path")

script_content=$(echo "$script_content" | sed -E "s/^BENCHMARK=\"[^\"]+\"/BENCHMARK=\"${Cur_Benchmark}\"/")

# Iterate over all components to flip
for component in "${components_to_flip_list[@]}"; do
    # Modify components_to_flip value in script
    dest_path="${dest_dir}/${benchmark}_${kernel}.csv"

    if [ -f "$dest_path" ]; then
        skipping_component="Skipping $filename for component $component, $dest_path already exists."
        echo "$skipping_component"
        continue 
    fi   

    scrip_content=$(echo "$script_content" | sed -E "s/^components_to_flip=[[:space:]]*[0-9]+(\s*#.*)?$/components_to_flip=${component}/")
    # If component == 2, check if SMEM_SIZE_BITS is 0
    if [ "$component" -eq 2 ]; then
        smem_size_bits=$(echo "$modified_content" | grep -E '^SMEM_SIZE_BITS=' | sed -E 's/^SMEM_SIZE_BITS=\s*([0-9]+).*$/\1/')
        if [ -z "$smem_size_bits" ]; then
            echo "SMEM_SIZE_BITS not found in $filename, skipping component $component."
            continue
        elif [ "$smem_size_bits" -eq 0 ]; then
            echo "Skipping $filename for component $component, SMEM_SIZE_BITS=0."
         #   modified_content=$(echo "$script_content" | sed -E "s/^SMEM_SIZE_BITS=\s*[0-9]+(\s*#.*)?$/SMEM_SIZE_BITS=${component}/")
                temp_script_path="temp_run_${kernel}_${component}.sh"
                echo "$modified_content" > "$temp_script_path"
            continue
        fi
    fi
    # rm *.csv
    modified_content=$(echo "$scrip_content" | sed -E "s/^SMEM_SIZE_BITS=\s*[0-9]+(\s*#.*)?$/SMEM_SIZE_BITS=111/")

    # Write modified script to temporary file
    temp_script_path="temp_run_${kernel}_${component}.sh"
    echo "$modified_content" > "$temp_script_path"

    # Make temporary script executable
    chmod +x "$temp_script_path"

    # Run temporary script
    echo "Running $temp_script_path, component $component."
    source setup_environment   # Load environment variables if needed

    ./"$temp_script_path"
 # Process output file
    hardware_name="${hardware_dict[$component]}"
    dest_filename="${hardware_name}_${benchmark}_${kernel}.csv"
    dest_dir="${directories[$component]}"
    # dest_path="${dest_dir}/${benchmark}_${kernel}.csv"
    output_csv_path="output.csv"  # Assume output.csv is in the current directory

    if [ -f "$output_csv_path" ]; then
        # Copy output.csv to backup file
        cp -f "$output_csv_path" "$dest_filename"
        # Move output.csv to target directory
        mv -f "$output_csv_path" "$dest_path"
    else
        echo "output.csv not found after running $temp_script_path, please check script output."
        continue
    fi

    # Remove temporary script
    # rm -f "$temp_script_path"
done


