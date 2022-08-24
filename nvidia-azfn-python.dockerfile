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


