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

collection_folder="$(grep -m 1 "^collection_folder=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
object_store_bucket="$(grep -m 1 "^object_store_bucket=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"
object_store_ligands_prefix="$(grep -m 1 "^object_store_ligands_prefix=" ${controlfile} | tr -d '[[:space:]]' | awk -F '[=#]' '{print $2}')"

pushd ${collection_folder}
echo ${collection_folder}

rm /tmp/sync

for dir in $(ls -d */); do
	echo "$i"
	pushd $dir
	for file in *.tar; do
		echo "  - $file"
		tar -xf $file 
	done
	echo "aws s3 sync ${dir} s3://${object_store_bucket}/${object_store_ligands_prefix}/${dir} --exclude *.tar" >> /tmp/sync
	popd
done

#aws s3 sync . s3://${object_store_bucket}/${object_store_ligands_prefix} --exclude *.tar
parallel -j 16 --files < /tmp/sync

popd
