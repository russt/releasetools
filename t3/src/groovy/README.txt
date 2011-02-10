Here is how I prepared groovy for tools distribution:

wget http://dist.groovy.codehaus.org/distributions/groovy-binary-1.7.7.zip
unquarantine groovy-binary-1.7.7.zip
unzip groovy-binary-1.7.7.zip
mv groovy-binary-1.7.7 tmp
cd tmp
unquarantine `walkdir -f`
rm -rf embeddable bin/*.bat *.txt
chmod +x -r bin/*
tar cf ../groovy.btz *

