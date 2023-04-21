FROM nvidia/cuda:10.2-devel-ubuntu18.04

##############################################################################
# Temporary Installation Directory
##############################################################################
ENV STAGE_DIR=/tmp
RUN mkdir -p ${STAGE_DIR}

##############################################################################
# Installation/Basic Utilities
##############################################################################
RUN  sed -i s@/archive.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list
RUN  sed -i s@/security.ubuntu.com/@/mirrors.aliyun.com/@g /etc/apt/sources.list
RUN rm /etc/apt/sources.list.d/nvidia-ml.list && rm /etc/apt/sources.list.d/cuda.list && apt-get clean
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        software-properties-common build-essential autotools-dev \
        nfs-common pdsh \
        cmake g++ gcc \
        curl wget vim tmux emacs less unzip \
        htop iftop iotop ca-certificates openssh-client openssh-server \
        rsync iputils-ping net-tools sudo \
        llvm-9-dev libsndfile-dev \
        libcupti-dev \
        libjpeg-dev \
        libpng-dev \
        language-pack-zh-hans \
        screen jq psmisc dnsutils lsof musl-dev systemd


##############################################################################
# Installation Latest Git
##############################################################################
RUN add-apt-repository ppa:git-core/ppa -y && \
        apt-get update && \
        apt-get install -y git && \
        git --version


##############################################################################
# Mellanox OFED
##############################################################################
RUN apt-get install -y libnuma-dev  libnuma-dev libcap2
ENV MLNX_OFED_VERSION=5.1-2.5.8.0
COPY MLNX_OFED_LINUX-${MLNX_OFED_VERSION}-ubuntu18.04-x86_64.tgz ${STAGE_DIR}
RUN cd ${STAGE_DIR} && \
    tar xvfz MLNX_OFED_LINUX-${MLNX_OFED_VERSION}-ubuntu18.04-x86_64.tgz && \
    cd MLNX_OFED_LINUX-${MLNX_OFED_VERSION}-ubuntu18.04-x86_64 && \
    PATH=/usr/bin:$PATH ./mlnxofedinstall --user-space-only --without-fw-update --umad-dev-rw --all -q && \
    cd ${STAGE_DIR} && \
    rm -rf ${STAGE_DIR}/MLNX_OFED_LINUX-${MLNX_OFED_VERSION}-ubuntu18.04-x86_64*

##############################################################################
# nv_peer_mem
##############################################################################
ENV NV_PEER_MEM_VERSION=1.1
ENV NV_PEER_MEM_TAG=1.1-0
RUN mkdir -p ${STAGE_DIR} && \
        git clone https://github.com/Mellanox/nv_peer_memory.git --branch ${NV_PEER_MEM_TAG} ${STAGE_DIR}/nv_peer_memory && \
        cd ${STAGE_DIR}/nv_peer_memory && \
        ./build_module.sh && \
        cd ${STAGE_DIR} && \
        tar xzf ${STAGE_DIR}/nvidia-peer-memory_${NV_PEER_MEM_VERSION}.orig.tar.gz && \
        cd ${STAGE_DIR}/nvidia-peer-memory-${NV_PEER_MEM_VERSION} && \
        apt-get update && \
        apt-get install -y dkms && \
        dpkg-buildpackage -us -uc && \
        dpkg -i ${STAGE_DIR}/nvidia-peer-memory_${NV_PEER_MEM_TAG}_all.deb

##############################################################################
# OPENMPI
##############################################################################
ENV OPENMPI_BASEVERSION=4.0
ENV OPENMPI_VERSION=${OPENMPI_BASEVERSION}.5
COPY openmpi-4.0.5.tar.gz  ${STAGE_DIR}
COPY libevent-2.0.22-stable.tar.gz  ${STAGE_DIR}
RUN cd ${STAGE_DIR} && \
    tar -zxvf libevent-2.0.22-stable.tar.gz && \
    cd libevent-2.0.22-stable && \
    ./configure --prefix=/usr && \
    make && make install
RUN cd ${STAGE_DIR} && \
    tar --no-same-owner -xzf openmpi-4.0.5.tar.gz && \
    cd openmpi-${OPENMPI_VERSION} && \
    ./configure --prefix=/usr/local/openmpi-${OPENMPI_VERSION} && \
    make -j"$(nproc)" install  && \
    ln -s /usr/local/openmpi-${OPENMPI_VERSION} /usr/local/mpi && \
    #Sanity check:
    test -f /usr/local/mpi/bin/mpic++ && \
    cd ${STAGE_DIR} && \
    rm -r ${STAGE_DIR}/openmpi-${OPENMPI_VERSION}
ENV PATH=/usr/local/mpi/bin:${PATH} \
    LD_LIBRARY_PATH=/usr/local/lib:/usr/local/mpi/lib:/usr/local/mpi/lib64:${LD_LIBRARY_PATH}
#Create a wrapper for OpenMPI to allow running as root by default
RUN mv /usr/local/mpi/bin/mpirun /usr/local/mpi/bin/mpirun.real && \
    echo '#!/bin/bash' > /usr/local/mpi/bin/mpirun && \
    echo 'mpirun.real --allow-run-as-root --prefix /usr/local/mpi "$@"' >> /usr/local/mpi/bin/mpirun && \
    chmod a+x /usr/local/mpi/bin/mpirun

##############################################################################
# Python
##############################################################################
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHON_VERSION=3
RUN apt-get install -y python3.8 python3.8-dev && \
        rm -f /usr/bin/python && \
        ln -sf /usr/bin/python3.8 /usr/bin/python3

RUN apt-get install -y language-pack-zh-hans \
    python3-pip

RUN pip3 install -i https://pypi.douban.com/simple pip -U \
  && pip3 config set global.index-url https://pypi.douban.com/simple \
  && pip3 config set global.trusted-host pypi.douban.com
RUN pip3 install pyyaml
RUN pip3 install ipython


##############################################################################
# TensorFlow
##############################################################################
# ENV TENSORFLOW_VERSION=1.15.2
# RUN pip install tensorflow-gpu==${TENSORFLOW_VERSION}

##############################################################################
# Some Packages
##############################################################################
RUN apt-get update && \
        apt-get install -y --no-install-recommends \
        libsndfile-dev \
        libcupti-dev \
        libjpeg-dev \
        libpng-dev \
        screen \
        libaio-dev
RUN pip3 install psutil \
        yappi \
        cffi \
        ipdb \
        pandas \
        matplotlib \
        py3nvml \
        pyarrow \
        graphviz \
        astor \
        boto3 \
        tqdm \
        sentencepiece \
        msgpack \
        requests \
        pandas \
        sphinx \
        sphinx_rtd_theme \
        scipy \
        numpy \
        # sklearn \
        scikit-learn \
        nvidia-ml-py3 \
        #mpi4py \
        cupy-cuda100

# ##############################################################################
# ## SSH daemon port inside container cannot conflict with host OS port
# ###############################################################################
# ENV SSH_PORT=2222
# RUN cat /etc/ssh/sshd_config > ${STAGE_DIR}/sshd_config && \
#         sed "0,/^#Port 22/s//Port ${SSH_PORT}/" ${STAGE_DIR}/sshd_config > /etc/ssh/sshd_config

##############################################################################
# PyTorch
##############################################################################
ENV PYTORCH_VERSION=1.8.0
ENV TORCHVISION_VERSION=0.9.0
ENV TENSORBOARDX_VERSION=1.8
RUN pip3 install torch==${PYTORCH_VERSION}
RUN pip3 install torchvision==${TORCHVISION_VERSION}
RUN pip3 install tensorboardX==${TENSORBOARDX_VERSION}

##############################################################################
# PyYAML build issue
# https://stackoverflow.com/a/53926898
##############################################################################
RUN rm -rf /usr/lib/python3/dist-packages/yaml && \
        rm -rf /usr/lib/python3/dist-packages/PyYAML-*

##############################################################################
## Add deepspeed user
###############################################################################
# Add a deepspeed user with user id 8877
#RUN useradd --create-home --uid 8877 deepspeed
RUN useradd --create-home --uid 1000 --shell /bin/bash deepspeed
RUN usermod -aG sudo deepspeed
RUN echo "deepspeed ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
# # Change to non-root privilege
USER deepspeed

##############################################################################
# DeepSpeed
##############################################################################
# USER deepspeed好像行不通
USER root
RUN git clone https://github.com/microsoft/DeepSpeed.git ${STAGE_DIR}/DeepSpeed
# RUN cd ${STAGE_DIR}/DeepSpeed && \
#         git checkout . && \
#         git checkout master && \
#         sudo ln -sf /usr/bin/pip3 /usr/bin/pip && \
#         sudo ln -sf /usr/bin/python3.8 /usr/bin/python && \
#         ./install.sh --pip_sudo

# 用pip3 install deepspeed==0.7.x 或 pip3 install deepspeed==0.6.x 代替
RUN pip3 install deepspeed==0.7.6
RUN sudo ln -sf /usr/bin/pip3 /usr/bin/pip && \
        sudo ln -sf /usr/bin/python3.8 /usr/bin/python

RUN rm -rf ${STAGE_DIR}/DeepSpeed
RUN python3 -c "import deepspeed; print(deepspeed.__version__)"



##############################################################################
## SSH daemon port inside container cannot conflict with host OS port
###############################################################################

#设置 SSH 会话保持活跃的时间间隔为 30 秒
RUN echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config
RUN cp /etc/ssh/sshd_config ${STAGE_DIR}/sshd_config && \
    sed "0,/^#Port 22/s//Port 22/" ${STAGE_DIR}/sshd_config > /etc/ssh/sshd_config
    
#将容器内的ssh配置文件（/etc/ssh/sshd_config）备份到${STAGE_DIR}/sshd_config目录下，并将端口号改为22（默认端口）后再写入到ssh配置文件中，以便于在构建镜像时使用。
ARG SSH_PORT=22
RUN cat /etc/ssh/sshd_config > ${STAGE_DIR}/sshd_config && \
    echo "PasswordAuthentication no" >> ${STAGE_DIR}/sshd_config && \
    sed "0,/^Port 22/s//Port ${SSH_PORT}/" ${STAGE_DIR}/sshd_config > /etc/ssh/sshd_config
EXPOSE ${SSH_PORT}

# ssh 免密
RUN echo "StrictHostKeyChecking no \nUserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config && \
 ssh-keygen -t rsa -f ~/.ssh/id_rsa -N "" && cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && \
   chmod og-wx ~/.ssh/authorized_keys
#Set SSH config
COPY ssh-env-config.sh /usr/local/bin/ssh-env-config.sh
RUN chmod +x /usr/local/bin/ssh-env-config.sh
CMD /etc/init.d/ssh start && ssh-env-config.sh /bin/bash


RUN sudo mkdir /run/sshd
CMD ["/usr/sbin/sshd", "-D"]
