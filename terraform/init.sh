MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/sh
set -ex
sed -i 's/KUBELET_EXTRA_ARGS=$2/KUBELET_EXTRA_ARGS="$2 --max-pods=2048"/' /etc/eks/bootstrap.sh

--==MYBOUNDARY==--