#!/bin/bash

# 配置项
DEFAULT_VM_NAME="linux-vm"
DEFAULT_MEM_SIZE=4096  # 内存大小(MB)
DEFAULT_VCPUS=2        # CPU核心数
DEFAULT_DISK_SIZE=20   # 磁盘大小(GB)
DEFAULT_OS_VARIANT="rhel8.0"  # 操作系统类型

# 状态文件，用于记录安装进度
STATE_FILE="/var/run/vm_install.state"

# 帮助信息
show_usage() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  --name <name>       虚拟机名称 (默认: $DEFAULT_VM_NAME)"
    echo "  --memory <size>     内存大小(MB) (默认: $DEFAULT_MEM_SIZE)"
    echo "  --vcpus <num>       CPU核心数 (默认: $DEFAULT_VCPUS)"
    echo "  --disk <size>       磁盘大小(GB) (默认: $DEFAULT_DISK_SIZE)"
    echo "  --iso <path>        ISO镜像路径 (必需)"
    echo "  --os-variant <os>   操作系统类型 (默认: $DEFAULT_OS_VARIANT)"
    echo "  --network <type>    网络类型 (默认: default)"
    echo "  --help             显示此帮助信息"
}

# 参数解析
VM_NAME=$DEFAULT_VM_NAME
MEM_SIZE=$DEFAULT_MEM_SIZE
VCPUS=$DEFAULT_VCPUS
DISK_SIZE=$DEFAULT_DISK_SIZE
ISO_PATH=""
OS_VARIANT=$DEFAULT_OS_VARIANT
NETWORK_TYPE="default"

while [ $# -gt 0 ]; do
    case "$1" in
        --name)
            VM_NAME="$2"
            shift 2
            ;;
        --memory)
            MEM_SIZE="$2"
            shift 2
            ;;
        --vcpus)
            VCPUS="$2"
            shift 2
            ;;
        --disk)
            DISK_SIZE="$2"
            shift 2
            ;;
        --iso)
            ISO_PATH="$2"
            shift 2
            ;;
        --os-variant)
            OS_VARIANT="$2"
            shift 2
            ;;
        --network)
            NETWORK_TYPE="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "错误：未知选项 $1"
            show_usage
            exit 1
            ;;
    esac
done

# 检查必需参数
if [ -z "$ISO_PATH" ]; then
    echo "错误：必须指定ISO镜像路径 (--iso)"
    show_usage
    exit 1
fi

# 检查是否以root权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "错误：此脚本必须以root权限运行"
    exit 1
fi

# 检查必需工具
check_requirements() {
    local missing_tools=0
    
    # 检查virt-install命令
    if ! command -v virt-install &> /dev/null; then
        echo "错误：未找到virt-install命令。请安装virtinst包。"
        missing_tools=1
    fi
    
    # 检查virsh命令
    if ! command -v virsh &> /dev/null; then
        echo "错误：未找到virsh命令。请安装libvirt-client包。"
        missing_tools=1
    fi
    
    # 检查qemu-img命令
    if ! command -v qemu-img &> /dev/null; then
        echo "错误：未找到qemu-img命令。请安装qemu-img包。"
        missing_tools=1
    fi
    
    if [ $missing_tools -ne 0 ]; then
        echo "请安装缺失的工具后重试。"
        exit 1
    fi
}

# 检查libvirt服务状态
check_libvirt_service() {
    if ! systemctl is-active --quiet libvirtd; then
        echo "正在启动libvirtd服务..."
        systemctl start libvirtd
        if [ $? -ne 0 ]; then
            echo "错误：无法启动libvirtd服务"
            exit 1
        fi
    fi
}

# 检查ISO文件
check_iso() {
    if [ ! -f "$ISO_PATH" ]; then
        echo "错误：ISO文件不存在：$ISO_PATH"
        exit 1
    fi
}

# 检查虚拟机名称是否已存在
check_vm_exists() {
    if virsh dominfo "$VM_NAME" &> /dev/null; then
        echo "错误：虚拟机 '$VM_NAME' 已存在"
        exit 1
    fi
}

# 创建虚拟机
create_vm() {
    echo "正在创建虚拟机..."
    
    virt-install \
        --name="$VM_NAME" \
        --memory=$MEM_SIZE \
        --vcpus=$VCPUS \
        --disk size=$DISK_SIZE \
        --os-variant="$OS_VARIANT" \
        --network network=$NETWORK_TYPE \
        --graphics vnc \
        --cdrom="$ISO_PATH" \
        --boot cdrom,hd 
    
    if [ $? -ne 0 ]; then
        echo "错误：创建虚拟机失败"
        exit 1
    fi
}

# 主程序
echo "=== 开始安装Linux虚拟机 ==="
echo "虚拟机名称: $VM_NAME"
echo "内存大小: ${MEM_SIZE}MB"
echo "CPU核心数: $VCPUS"
echo "磁盘大小: ${DISK_SIZE}GB"
echo "ISO镜像: $ISO_PATH"
echo "操作系统类型: $OS_VARIANT"
echo "网络类型: $NETWORK_TYPE"
echo "========================"

# 执行检查
check_requirements
check_libvirt_service
check_iso
check_vm_exists

# 创建虚拟机
create_vm

echo "=== 虚拟机创建完成 ==="
echo "你可以使用以下命令连接到虚拟机控制台："
echo "virsh console $VM_NAME"
echo "或使用virt-manager图形界面工具连接"

exit 0