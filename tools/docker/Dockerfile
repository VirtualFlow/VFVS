# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# This file is part of VirtualFlow.
#
# VirtualFlow is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
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

RUN yum update -y && yum -y install python3
RUN pip3 install boto3

ADD . /opt/vf/tools

ENV USER ec2-user

RUN chmod +x -R /opt/vf/tools/*.sh /opt/vf/tools/*.py /opt/vf/tools/templates/*.sh /opt/vf/tools/templates/*.py

WORKDIR /

ENTRYPOINT ["/opt/vf/tools/templates/template1.awsbatch.sh"]

