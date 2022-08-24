ARG HOST_VERSION=4.9.1
# DotNet 6.0 image where we will build the Azure Function project
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS runtime-image
ARG HOST_VERSION

ENV PublishWithAspNetCoreTargetManifest=false

# Build Azure Function project
RUN BUILD_NUMBER=$(echo ${HOST_VERSION} | cut -d'.' -f 3) && \
	git clone --branch v${HOST_VERSION} https://github.com/Azure/azure-functions-host /src/azure-functions-host && \
	cd /src/azure-functions-host && \
	HOST_COMMIT=$(git rev-list -1 HEAD) && \
	dotnet publish -v q /p:BuildNumber=$BUILD_NUMBER /p:CommitHash=$HOST_COMMIT src/WebJobs.Script.WebHost/WebJobs.Script.WebHost.csproj -c Release --output /azure-functions-host --runtime linux-x64 && \
	mv /azure-functions-host/workers /workers && mkdir /azure-functions-host/workers && \
	rm -rf /root/.local /root/.nuget /src

# Install AzFn Extension Bundle
RUN apt-get update && \
	apt-get install -y gnupg wget unzip curl && \
	EXTENSION_BUNDLE_VERSION_V2=2.15.0 && \
	EXTENSION_BUNDLE_FILENAME_V2=Microsoft.Azure.Functions.ExtensionBundle.${EXTENSION_BUNDLE_VERSION_V2}_linux-x64.zip && \
	wget https://functionscdn.azureedge.net/public/ExtensionBundles/Microsoft.Azure.Functions.ExtensionBundle/$EXTENSION_BUNDLE_VERSION_V2/$EXTENSION_BUNDLE_FILENAME_V2 && \
	mkdir -p /FuncExtensionBundles/Microsoft.Azure.Functions.ExtensionBundle/$EXTENSION_BUNDLE_VERSION_V2 && \
	unzip /$EXTENSION_BUNDLE_FILENAME_V2 -d /FuncExtensionBundles/Microsoft.Azure.Functions.ExtensionBundle/$EXTENSION_BUNDLE_VERSION_V2 && \
	rm -f /$EXTENSION_BUNDLE_FILENAME_V2 &&\
	EXTENSION_BUNDLE_VERSION_V3=3.13.0 && \
	EXTENSION_BUNDLE_FILENAME_V3=Microsoft.Azure.Functions.ExtensionBundle.${EXTENSION_BUNDLE_VERSION_V3}_linux-x64.zip && \
	wget https://functionscdn.azureedge.net/public/ExtensionBundles/Microsoft.Azure.Functions.ExtensionBundle/$EXTENSION_BUNDLE_VERSION_V3/$EXTENSION_BUNDLE_FILENAME_V3 && \
	mkdir -p /FuncExtensionBundles/Microsoft.Azure.Functions.ExtensionBundle/$EXTENSION_BUNDLE_VERSION_V3 && \
	unzip /$EXTENSION_BUNDLE_FILENAME_V3 -d /FuncExtensionBundles/Microsoft.Azure.Functions.ExtensionBundle/$EXTENSION_BUNDLE_VERSION_V3 && \
	rm -f /$EXTENSION_BUNDLE_FILENAME_V3 &&\
	find /FuncExtensionBundles/ -type f -exec chmod 644 {} \;

# Nvidia Cuda Ubutu 20.04 image
FROM nvidia/cuda:11.7.1-devel-ubuntu20.04 AS running-image

# Set variables for Python, DotNet and AzFn (and dependencies) installation/configuration 
ENV ACCEPT_EULA=Y \
	NUGET_XMLDOC_MODE=skip \
	DOTNET_RUNNING_IN_CONTAINER=true \
	DOTNET_USE_POLLING_FILE_WATCHER=true

# Python 3.9 Installation with dependencies
RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install tzdata \
	&& apt-get install -y --no-install-recommends software-properties-common \
	&& add-apt-repository ppa:deadsnakes/ppa \
	&& apt-get install -y python3.9 \
	&& apt-get install -y libpython3.9-dev \
	&& apt-get install -y python3-pip \
	&& apt-get install -y python3-dev \
	&& apt-get install -y cmake \
	&& apt-get install -y pkg-config \
	&& rm -rf /var/lib/apt/lists/*

# Useful symlinks that are expected to exist
RUN cd /usr/bin \
	&& ln -s pydoc3.9 pydoc3 -f \
	&& ln -s pygettext3.9 pygettext3 -f \
	&& ln -s pip3 pip -f \
	&& ln -s python3.9 python3 -f \
	&& ln -s python3.9 python -f

# Ensure cuda is installed
RUN apt-get update \
	&& apt-get install -y cuda 

# Other dependencies
RUN apt-get update \
    && apt-get install -y libglib2.0-0 libsm6 libxext6 libxrender-dev \
    && apt-get install -y libgomp1 

# Copy AzFn binaries to main image
COPY --from=runtime-image ["/azure-functions-host", "/azure-functions-host"]
COPY --from=runtime-image [ "/workers/python/3.9/LINUX", "/azure-functions-host/workers/python/3.9/LINUX" ]
COPY --from=runtime-image [ "/workers/python/worker.config.json", "/azure-functions-host/workers/python" ]
COPY --from=runtime-image [ "/FuncExtensionBundles", "/FuncExtensionBundles" ]

# Variables for AzFn
ENV FUNCTIONS_WORKER_RUNTIME_VERSION=3.9 \
	FUNCTIONS_WORKER_RUNTIME=python \
	ASPNETCORE_CONTENTROOT=/azure-functions-host

CMD [ "/azure-functions-host/Microsoft.Azure.WebJobs.Script.WebHost" ]
