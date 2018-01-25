Je me suis principalement concentré sur le serveur, le client est juste là pour envoyer des données au serveur et faire une POC. (J'ai principalement développé le serveur avec netcat)

Le serveur crée un thread dédié à chaque connexion puis pour chaque log il vient les ajouter à une queue qui seront traité par un thread dédié.




# Perl-Project
Small rsyslog-like in Perl for a school projet

# Ressources : 
http://xmodulo.com/how-to-write-simple-tcp-server-and-client-in-perl.html
Also many pages of PerlMonks
