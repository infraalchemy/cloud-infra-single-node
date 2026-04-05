FROM nginx:1.21.4

# Copy custom Nginx config for your site
COPY ./nginx/pglearn.panglobal.org.conf /etc/nginx/sites-available/pglearn.panglobal.org.conf

# Remove default Nginx config if it exists (optional)
RUN rm -f /etc/nginx/sites-available/default

# Create a symbolic link to the site configuration in sites-enabled
RUN ln -s /etc/nginx/sites-available/pglearn.panglobal.org.conf /etc/nginx/sites-enabled/

# Expose HTTP and HTTPS ports
EXPOSE 80 443

