import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_connectivity.dart';
import '../models/client.dart';
import '../models/queue_state.dart';
import '../providers/connectivity_provider.dart';
import '../providers/queue_provider.dart';
import '../widgets/client_card.dart';
import '../widgets/loading_widget.dart';
import '../widgets/offline_banner.dart';
import '../widgets/queue_empty_widget.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<QueueProvider>();
      if (provider.hasMore && !provider.isLoadingMore) {
        provider.loadMore();
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleAddClient() {
    final name = _textController.text.trim();
    if (name.isNotEmpty) {
      context.read<QueueProvider>().addClient(name);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    AppConnectivity connectivityStatus = AppConnectivity.online;
    try {
      final connectivityProvider =
          Provider.of<ConnectivityProvider?>(context, listen: true);
      if (connectivityProvider != null) {
        connectivityStatus = connectivityProvider.status;
      }
    } catch (_) {
      connectivityStatus = AppConnectivity.online;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Room'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Banner showing connectivity and backend health
          OfflineBanner(status: connectivityStatus),

          // Client input section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Enter name',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _handleAddClient(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _handleAddClient,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),

          // Main queue body with state transitions
          Expanded(
            child: Consumer<QueueProvider>(
              builder: (context, provider, _) {
                QueueState state = QueueState.loaded;
                try {
                  state = provider.state;
                } catch (_) {
                  state = provider.clients.isEmpty
                      ? QueueState.empty
                      : QueueState.loaded;
                }

                switch (state) {
                  case QueueState.loading:
                    return const LoadingWidget(message: 'Loading queue...');

                  case QueueState.empty:
                    return const QueueEmptyWidget();

                  case QueueState.error:
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            provider.errorMessage ?? 'An error occurred',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => provider.fetchInitialQueue(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );

                  case QueueState.initial:
                  case QueueState.loaded:
                  case QueueState.refreshing:
                  case QueueState.loadingMore:
                    if (provider.clients.isEmpty) {
                      return const QueueEmptyWidget();
                    }

                    bool isLoadingMore = false;
                    try {
                      isLoadingMore = provider.isLoadingMore;
                    } catch (_) {
                      isLoadingMore = false;
                    }

                    return RefreshIndicator(
                      onRefresh: () => provider.fetchInitialQueue(),
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: provider.clients.length +
                            (isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == provider.clients.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final rawClient = provider.clients[index];
                          final Client client = rawClient is Client
                              ? rawClient
                              : Client.fromLocalMap(
                                  Map<String, dynamic>.from(rawClient as Map),
                                );

                          return Dismissible(
                            key: Key(client.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) {
                              provider.removeClient(client.id);
                            },
                            child: ClientCard(client: client),
                          );
                        },
                      ),
                    );
                }
              },
            ),
          ),

          // Next Client Action Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('nextClientButton'),
                onPressed: () {
                  context.read<QueueProvider>().nextClient();
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next Client'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
