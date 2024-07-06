#!/bin/bash
apt update
apt install -y apache2

cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Hello World</title>
</head>
<body>
    <h1>Hello from $(hostname)</h1>
</body>
</html>
EOF

systemctl restart apache2
