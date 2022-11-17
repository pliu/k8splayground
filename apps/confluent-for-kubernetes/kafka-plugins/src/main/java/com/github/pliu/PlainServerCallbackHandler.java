package com.github.pliu;

import java.io.IOException;
import java.util.List;
import java.util.Map;

import javax.security.auth.callback.Callback;
import javax.security.auth.callback.NameCallback;
import javax.security.auth.callback.UnsupportedCallbackException;
import javax.security.auth.login.AppConfigurationEntry;

import org.apache.kafka.common.security.plain.PlainAuthenticateCallback;
import org.apache.kafka.common.security.auth.AuthenticateCallbackHandler;
import org.apache.kafka.common.KafkaException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class PlainServerCallbackHandler implements AuthenticateCallbackHandler {
    private static Logger log = LoggerFactory.getLogger("peng");
    private List<AppConfigurationEntry> jaasConfigEntries;

    @Override
    public void configure(Map<String, ?> configs, String mechanism, List<AppConfigurationEntry> jaasConfigEntries) {
        log.info("PENG: PlainServerCallbackHandler " + mechanism);
        this.jaasConfigEntries = jaasConfigEntries;
    }

    @Override
    public void handle(Callback[] callbacks) throws IOException, UnsupportedCallbackException {
        String username = null;
        for (Callback callback : callbacks) {
            if (callback instanceof NameCallback)
                username = ((NameCallback) callback).getDefaultName();
            else if (callback instanceof PlainAuthenticateCallback) {
                PlainAuthenticateCallback plainCallback = (PlainAuthenticateCallback) callback;
                boolean authenticated = authenticate(username, plainCallback.password());
                plainCallback.authenticated(authenticated);
            } else
                throw new UnsupportedCallbackException(callback);
        }
    }

    protected boolean authenticate(String username, char[] password) throws IOException {
        if (username == null)
            return false;
        else {
            // Return true if password matches expected password
            log.info("PENG: " + username + ":" + new String(password));
            return true;
        }
    }

    @Override
    public void close() throws KafkaException {
    }
}
