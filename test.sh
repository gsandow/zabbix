#!/bin/bash
# =====================================
#     Author: sandow
#     Email: j.k.yulei@gmail.com
#     HomePage: www.gsandow.com
# =====================================

redis_status=$(printf  "auth EeQfVrWJtvBiw4bk\r\ninfo\r\n"|nc 10.8.32.57  6379 )
for a in redis_status;do
        echo ${redis_status[a]}
done
