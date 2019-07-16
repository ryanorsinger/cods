# variables $domain, $port

# The username will be the domain name with all `.`s replaced by `-`s.
# Technically a linux username can contain `.`s, but this causes some issues
# with systemd and sudoers.
username=${domain//./-}

echo "- Creating User and Group For ${domain}"
sudo useradd --no-create-home ${username} --shell /bin/false
# add admin users to new group
for user in $(ls /home) ; do sudo usermod -a -G ${username} ${user} ; done
# and ngnix
sudo usermod -a -G ${username} www-data

echo "- Creating Site Directory -- /srv/${domain}"
sudo mkdir -p /srv/${domain}/public
sudo chown -R ${username}:${username} /srv/${domain}
sudo chmod g+srw /srv/${domain}
sudo chmod g+srw /srv/${domain}/public

echo '- Creating Nginx Config'
sudo cp /srv/.templates/site.nginx.conf /etc/nginx/sites-available/${domain}
sudo sed -i\
	-e s/{{domain}}/${domain}/g\
	-e s/{{port}}/${port}/g\
	/etc/nginx/sites-available/${domain}

sudo ln -s /etc/nginx/sites-available/${domain} /etc/nginx/sites-enabled/${domain}

echo '- Restarting Nginx'
sudo systemctl restart nginx

# create the service
echo '- Creating Systemd Service File'
sudo cp /srv/.templates/service-unit /etc/systemd/system/${domain}.service
sudo sed -i\
	-e s/{{user}}/${username}/g\
	-e s/{{group}}/${username}/g\
	-e s/{{domain}}/${domain}/g\
	-e "s!{{execstart}}!${execstart}!g"\
	/etc/systemd/system/${domain}.service

echo '- Enabling Service'
sudo systemctl daemon-reload
sudo systemctl enable ${domain}.service

echo '- Allow Service To Be Restarted Without A Password'
# We'll create a separate file with the permissions for manipulating the service
# for this site so that it is easier to clean up. The name of this file must not
# contain '.'s though, so we'll generate a file named after the domain with '-'s
# instead of '.'s
# see /etc/sudoers.d/README and man 5 sudoers
{
	echo "%web ALL=NOPASSWD: /bin/systemctl restart ${domain}"
	echo "%web ALL=NOPASSWD: /bin/journalctl --no-pager -o short-iso -u ${domain}"
	echo "%web ALL=NOPASSWD: /bin/journalctl -o short-iso -f -u ${domain}"
} | sudo EDITOR='tee' visudo -f /etc/sudoers.d/${username} >/dev/null
