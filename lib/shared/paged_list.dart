import 'package:flutter/material.dart';

import '../core/models/page.dart';
import 'widgets.dart';

/// A pull-to-refresh list that loads the next page near the end.
class PagedList<T> extends StatefulWidget {
  const PagedList({
    super.key,
    required this.load,
    required this.itemBuilder,
    this.empty,
    this.padding = const EdgeInsets.all(16),
    this.header,
  });

  final Future<PageOf<T>> Function(int page) load;
  final Widget Function(
    BuildContext context,
    T item,
    void Function(T updated) replace,
  )
  itemBuilder;
  final Widget? empty;
  final Widget? header;
  final EdgeInsets padding;

  @override
  State<PagedList<T>> createState() => PagedListState<T>();
}

class PagedListState<T> extends State<PagedList<T>> {
  final List<T> _items = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    await _next();
  }

  Future<void> _next() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = await widget.load(_page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _page = page.currentPage;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _error != null) {
      return ErrorView(error: _error!, onRetry: reload);
    }
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final header = widget.header;
    return RefreshIndicator(
      onRefresh: reload,
      child: _items.isEmpty
          ? ListView(children: [?header, widget.empty ?? const EmptyView()])
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.extentAfter < 300) _next();
                return false;
              },
              child: ListView.builder(
                padding: widget.padding,
                itemCount:
                    _items.length +
                    (header == null ? 0 : 1) +
                    (_hasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (header != null) {
                    if (i == 0) return header;
                    i--;
                  }
                  if (i >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return widget.itemBuilder(
                    context,
                    _items[i],
                    (updated) => setState(() => _items[i] = updated),
                  );
                },
              ),
            ),
    );
  }
}
