#!/bin/sh
# ----------------------------------------------------------------------------
#  Copyright 2001-2004 The Apache Software Foundation.
#  
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#  
#       http://www.apache.org/licenses/LICENSE-2.0
#  
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
# ----------------------------------------------------------------------------

#   Copyright (c) 2001-2002 The Apache Software Foundation.  All rights
#   reserved.

FOREHEAD_VERSION=1.0-beta-5

if [ -z "$MAVEN_OPTS" ] ; then
  MAVEN_OPTS="-Xmx512m -XX:MaxPermSize=128m"
fi

if [ -f /etc/mavenrc ] ; then
  . /etc/mavenrc
fi

if [ -f "$HOME/.mavenrc" ] ; then
  . "$HOME/.mavenrc"
fi

# OS specific support.  $var _must_ be set to either true or false.
cygwin=false;
darwin=false;
case "`uname`" in
  CYGWIN*) cygwin=true ;;
  Darwin*) darwin=true 
           if [ -z "$JAVA_VERSION" ] ; then
             JAVA_VERSION="CurrentJDK"
           else
             echo "Using Java version: $JAVA_VERSION"
           fi
           if [ -z "$JAVA_HOME" ] ; then
             JAVA_HOME=/System/Library/Frameworks/JavaVM.framework/Versions/${JAVA_VERSION}/Home
           fi
           ;;
esac

# try to find MAVEN in well known locations
[ -z "$MAVEN_HOME" -a -d /opt/maven ]		&& MAVEN_HOME=/opt/maven
[ -z "$MAVEN_HOME" -a -d "$HOME/maven" ]	&& MAVEN_HOME="$HOME/maven"

# Otherwise try to determine it from our invocation path
if [ -z "$MAVEN_HOME" ] ; then
  ## resolve links - $0 may be a link to maven's home
  saveddir=`pwd`

  # need this for relative symlinks
  PRG="$0"    
  while [ -h "$PRG" ]; do
      ls=`ls -ld "$PRG"`
      link=`expr "$ls" : '.*-> \(.*\)$'`
      if expr "$link" : '/.*' > /dev/null; then
          PRG="$link"
      else
          PRG="`dirname $PRG`/$link"
      fi
  done
    
  # Make it fully specified
  cd "`dirname \"$PRG\"`/.."
  MAVEN_HOME="`pwd -P`"

  cd "$saveddir"
fi

# For Cygwin, ensure paths are in UNIX format before anything is touched
if $cygwin ; then
  [ -n "$MAVEN_HOME" ] &&
    MAVEN_HOME=`cygpath --unix "$MAVEN_HOME"`
  [ -n "$MAVEN_HOME_LOCAL" ] &&
    MAVEN_HOME_LOCAL=`cygpath --unix "$MAVEN_HOME_LOCAL"`
  [ -n "$JAVA_HOME" ] &&
    JAVA_HOME=`cygpath --unix "$JAVA_HOME"`
  [ -n "$CLASSPATH" ] &&
    CLASSPATH=`cygpath --path --unix "$CLASSPATH"`
fi

if [ -z "$JAVACMD" ] ; then
  if [ -n "$JAVA_HOME"  ] ; then
    if [ -x "$JAVA_HOME/jre/sh/java" ] ; then
      # IBM's JDK on AIX uses strange locations for the executables
      JAVACMD="$JAVA_HOME/jre/sh/java"
    else
      JAVACMD="$JAVA_HOME/bin/java"
    fi
  else
    JAVACMD=java
  fi
fi

if [ ! -x "$JAVACMD" -a ! -x "$JAVACMD".exe ] ; then
  echo "Error: JAVA_HOME is not defined correctly."
  echo "  We cannot execute $JAVACMD"
  exit 1
fi

if [ -z "$JAVA_HOME" ] ; then
  echo "Warning: JAVA_HOME environment variable is not set."
  echo "  If build fails because sun.* classes could not be found"
  echo "  you will need to set the JAVA_HOME environment variable"
  echo "  to the installation directory of java."
fi

# For Cygwin, switch paths to Windows format before running java
if $cygwin; then
  [ -n "$MAVEN_HOME" ] &&
    MAVEN_HOME=`cygpath --path --windows "$MAVEN_HOME"`
  [ -n "$MAVEN_HOME_LOCAL" ] &&
    MAVEN_HOME_LOCAL=`cygpath --path --windows "$MAVEN_HOME_LOCAL"`
  [ -n "$JAVA_HOME" ] &&
    JAVA_HOME=`cygpath --path --windows "$JAVA_HOME"`
  [ -n "$HOME" ] &&
    HOME=`cygpath --path --windows "$HOME"`
fi

# For Darwin, use classes.jar for TOOLS_JAR
TOOLS_JAR="${JAVA_HOME}/lib/tools.jar"
if $darwin; then
  TOOLS_JAR="/System/Library/Frameworks/JavaVM.framework/Versions/${JAVA_VERSION}/Classes/classes.jar"
fi

MAIN_CLASS=com.werken.forehead.Forehead
if [ -n "$MAVEN_HOME_LOCAL" ]; then
  MAVEN_OPTS="$MAVEN_OPTS -Dmaven.home.local=${MAVEN_HOME_LOCAL}" 
fi
  
"$JAVACMD" \
  $MAVEN_OPTS \
  -classpath "${MAVEN_HOME}/lib/forehead-${FOREHEAD_VERSION}.jar" \
  "-Dforehead.conf.file=${MAVEN_HOME}/bin/forehead.conf"  \
  "-Dtools.jar=$TOOLS_JAR" \
  "-Dmaven.home=${MAVEN_HOME}" \
  $MAIN_CLASS "$@"

