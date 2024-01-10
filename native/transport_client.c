#include "transport_client.h"
#include <arpa/inet.h>
#include <netinet/in.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>
#include "transport_constants.h"
#include "transport_socket.h"

int transport_client_initialize_tcp(transport_client_t* client,
                                    transport_client_configuration_t* configuration,
                                    const char* ip,
                                    int32_t port)
{
    client->family = INET;
    memset(&client->inet_destination_address, 0, sizeof(client->inet_destination_address));
    client->inet_destination_address.sin_addr.s_addr = inet_addr(ip);
    client->inet_destination_address.sin_port = htons(port);
    client->inet_destination_address.sin_family = AF_INET;
    client->client_address_length = sizeof(client->inet_destination_address);
    int64_t result = transport_socket_create_tcp(
        configuration->socket_configuration_flags,
        configuration->socket_receive_buffer_size,
        configuration->socket_send_buffer_size,
        configuration->socket_receive_low_at,
        configuration->socket_send_low_at,
        configuration->ip_ttl,
        configuration->tcp_keep_alive_idle,
        configuration->tcp_keep_alive_max_count,
        configuration->tcp_keep_alive_individual_count,
        configuration->tcp_max_segment_size,
        configuration->tcp_syn_count);
    if (result < 0)
    {
        return result;
    }
    client->fd = result;
    return 0;
}

int transport_client_initialize_udp(transport_client_t* client,
                                    transport_client_configuration_t* configuration,
                                    const char* destination_ip,
                                    int32_t destination_port,
                                    const char* source_ip,
                                    int32_t source_port)
{
    client->family = INET;
    client->client_address_length = sizeof(struct sockaddr_in);

    memset(&client->inet_destination_address, 0, sizeof(client->inet_destination_address));
    client->inet_destination_address.sin_addr.s_addr = inet_addr(destination_ip);
    client->inet_destination_address.sin_port = htons(destination_port);
    client->inet_destination_address.sin_family = AF_INET;

    memset(&client->inet_source_address, 0, sizeof(client->inet_source_address));
    client->inet_source_address.sin_addr.s_addr = inet_addr(source_ip);
    client->inet_source_address.sin_port = htons(source_port);
    client->inet_source_address.sin_family = AF_INET;
    int64_t result = transport_socket_create_udp(
        configuration->socket_configuration_flags,
        configuration->socket_receive_buffer_size,
        configuration->socket_send_buffer_size,
        configuration->socket_receive_low_at,
        configuration->socket_send_low_at,
        configuration->ip_ttl,
        configuration->ip_multicast_interface,
        configuration->ip_multicast_ttl);
    if (result < 0)
    {
        return result;
    }
    client->fd = result;
    result = bind(client->fd, (struct sockaddr*)&client->inet_source_address, client->client_address_length);
    if (result < 0)
    {
        return result;
    }

    return 0;
}

int transport_client_initialize_unix_stream(transport_client_t* client,
                                            transport_client_configuration_t* configuration,
                                            const char* path)
{
    client->family = UNIX;
    memset(&client->unix_destination_address, 0, sizeof(client->unix_destination_address));
    client->unix_destination_address.sun_family = AF_UNIX;
    strcpy(client->unix_destination_address.sun_path, path);
    client->client_address_length = sizeof(client->unix_destination_address);
    int64_t result = transport_socket_create_unix_stream(
        configuration->socket_configuration_flags,
        configuration->socket_receive_buffer_size,
        configuration->socket_send_buffer_size,
        configuration->socket_receive_low_at,
        configuration->socket_send_low_at);
    if (result < 0)
    {
        return result;
    }
    client->fd = result;
    return 0;
}

struct sockaddr* transport_client_get_destination_address(transport_client_t* client)
{
    return client->family == INET ? (struct sockaddr*)&client->inet_destination_address : (struct sockaddr*)&client->unix_destination_address;
}

void transport_client_destroy(transport_client_t* client)
{
    if (client->family == UNIX)
    {
        unlink(client->unix_destination_address.sun_path);
        if (strlen(client->unix_source_address.sun_path))
        {
            unlink(client->unix_source_address.sun_path);
        }
    }
    free(client);
}