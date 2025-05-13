FROM ruby:3.3

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Copy the sample config to the actual config (performed at build time)
RUN cp spec/support/sample.docker.config.yml spec/support/config.yml

# Install any needed packages specified in Gemfile
RUN bundle install

# Command to run the application
CMD ["bash"]