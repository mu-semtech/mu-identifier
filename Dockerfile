FROM madnificent/elixir-server:1.14.0

ENV IEX_NAME=mu_identifier@ip
ENV IEX_COOKIE=mu-identifier

# NOTE: Upon removing this feature, we must throw an error on startup!  The interface is not fixed but if we stop loading these files we must error as per readme.
RUN sed -i "2i\\if [ -f /config/custom_session_reader.ex ] ; then cp /config/custom_session_reader.ex /app/lib/manipulators/incoming/custom_session_reader.ex ; fi" /startup.sh
RUN sed -i "2i\\if [ -f /config/custom_session_writer.ex ] ; then cp /config/custom_session_writer.ex /app/lib/manipulators/outgoing/custom_session_writer.ex; fi" /startup.sh

COPY . /app

RUN sh /setup.sh
