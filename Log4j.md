log4j CVE-2021-44228

Investigation 

Check java version

java -version

Check log4j binaries

ls /lib/common/log4j*

Check system for jvm.options file

find / -name filename.php

Check ps aux 

ps aux | grep -i formatMsgNoLookups

Remedation

How to Mitigate CVE-2021-44228

To mitigate the following options are available (see the advisory from Apache here):


Upgrade to Log4j v2.15.0

If you are using Log4j v2.10 or above, and cannot upgrade, then set the property:

log4j2.formatMsgNoLookups=true

Additionally, an environment variable can be set for these same affected versions:

LOG4J_FORMAT_MSG_NO_LOOKUPS=true

Remove the JndiLookup class from the classpath (does not always work)

For example, you can run a command like to remove the class from the log4j-core.

zip -q -d log4j-core-*.jar org/apache/logging/log4j/core/lookup/JndiLookup.class
