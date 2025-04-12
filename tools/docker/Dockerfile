# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# This file is part of VirtualFlow.
#
# VirtualFlow is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# VirtualFlow is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with VirtualFlow.  If not, see <https://www.gnu.org/licenses/>.


FROM amazonlinux:2

# Installing basic packages
RUN yum update -y && yum -y install python3 wget gcc tar make gcc-c++ zlib-devel gzip which
RUN yum install -y libicu libicu-devel
RUN pip3 install boto3 pandas pyarrow

ADD ./bin /opt/vf/tools/bin
ADD ./templates/*.py /opt/vf/tools/templates/
ADD ./templates/*.sh /opt/vf/tools/templates/

# Set library path
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

# Install Boost (1.70.0) with specific libraries needed for gwovina
WORKDIR /tmp
RUN wget -O boost_1_70_0.tar.gz https://sourceforge.net/projects/boost/files/boost/1.70.0/boost_1_70_0.tar.gz/download && \
    tar -xzf boost_1_70_0.tar.gz && \
    cd boost_1_70_0 && \
    ./bootstrap.sh --with-libraries=system,filesystem,thread,program_options && \
    ./b2 install && \
    ldconfig

# Add VirtualFlow tools and templates
ADD ./bin /opt/vf/tools/bin
ADD ./templates/*.py /opt/vf/tools/templates/
ADD ./templates/*.sh /opt/vf/tools/templates/

# Download and install gwovina
WORKDIR /tmp
RUN wget -q -O gwovina-1.0.tar.gz https://sourceforge.net/projects/gwovina/files/gwovina-1.0.tar.gz/download && \
    tar -xzf gwovina-1.0.tar.gz && \
    cd gwovina-1.0/build/linux/release && \
    make && \
    mv gwovina /opt/vf/tools/bin/gwovina

# Cleanup temporary files
RUN rm -rf /tmp/gwovina-1.0* /tmp/gwovina-1.0.tar.gz

# Ensure scripts in templates are executable
RUN chmod +x -R /opt/vf/tools/templates/*.sh /opt/vf/tools/templates/*.py

WORKDIR /

# Set the entrypoint for the container
ENTRYPOINT ["/opt/vf/tools/templates/template1.awsbatch.sh"]

