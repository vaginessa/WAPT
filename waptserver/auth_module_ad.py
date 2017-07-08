# copyright Tranquil IT Systems, all right reserved 2017


import os
import sys
try:
    wapt_root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
except:
    wapt_root_dir = 'c:/tranquilit/wapt'
sys.path.insert(0, os.path.join(wapt_root_dir))
sys.path.insert(0, os.path.join(wapt_root_dir, 'lib'))
sys.path.insert(0, os.path.join(wapt_root_dir, 'lib', 'site-packages'))

import re
import logging
import socket
import ldap

logger = logging.getLogger('waptserver')


def check_credentials_ad(username, password):

    dns_suffix = '.'.join(socket.getfqdn().split('.')[1:])
    dc_name = str(socket.gethostbyname(dns_suffix))
#    dc_name = 'newad.ad.tranquil.it'
    kerberos_realm = dns_suffix.upper()
    dc_base_dn = ','.join(['dc=%s' % x for x in dns_suffix.split('.')])
    wapt_admin_group = 'waptadmins'

    logger.debug('using dc %s for authentication, with base DN %s and kerberos realm %s ' % (dc_name, dc_base_dn, kerberos_realm))

    if ':' in dc_name:
        logger.error("DC_NAME must be a DNS server name or ip, not a ldap url")
        raise

    auth_ok = False

    bind_username = '%s@%s' % (username, kerberos_realm)

    ldap_filter = 'sAMAccountName=%s' % username
    attrs = ['memberOf']
    try:
        ldap.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)
        ldap_client = ldap.initialize('ldap://%s:389' % dc_name)
        ldap_client.set_option(ldap.OPT_REFERRALS, 0)
        ldap_client.simple_bind_s(bind_username, password)
        ldap_search_groups = ldap_client.search_s(dc_base_dn,
                                                  ldap.SCOPE_SUBTREE, ldap_filter, attrs)[0][1]['memberOf']
        logger.debug('user groups : %s ' % str(ldap_search_groups))

        for group in ldap_search_groups:
            if group.lower().startswith('cn=%s' % wapt_admin_group):
                logger.debug('%s is members of group %s ' % (username, wapt_admin_group))
                auth_ok = True

    except ldap.INVALID_CREDENTIALS:
        logger.error('Wrong username %s password' % bind_username)
        auth_ok = False
    except ldap.SERVER_DOWN:
        logger.error(traceback.print_exc())
        logger.error("AD server is here but we couldn't open a connection, please check ssl / starttls parameters")
        auth_ok = False
    finally:
        try:
            ldap_client.unbind()
        except:
            pass

    return auth_ok
