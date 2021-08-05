#!/usr/bin/env bash

# Copyright (C) 2019 Christoph Gorgulla
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

controlfile="../workflow/control/all.ctrl"

object_store_bucket_new="$(grep -m 1 "^object_store_bucket=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
object_store_job_data_new="$(grep -m 1 "^object_store_job_data_prefix=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
object_store_input_path="s3://${object_store_bucket_new}/${object_store_job_data_new}/input/vf_input.tar.gz"

rm -rf /tmp/vf_input
mkdir -p /tmp/vf_input/input-files
cp ${controlfile} /tmp/vf_input/
for file in ../input-files/*; do
	if [ "${file}" != "ligand-library" ]; then
		cp -r ../input-files /tmp/vf_input/
	fi
done

pushd /tmp
tar cf vf_input.tar vf_input
gzip vf_input.tar
popd

cp /tmp/vf_input.tar.gz ../workflow/

aws s3 cp ../workflow/vf_input.tar.gz ${object_store_input_path}
