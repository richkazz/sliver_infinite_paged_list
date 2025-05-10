import 'dart:async';
import 'package:flutter/material.dart';

// Type definitions (same as before)
/// Callback function to fetch a page of data.
typedef FetchPageCallback<T> =
    Future<List<T>> Function(int pageKey, int pageSize);

/// Builder function to create a widget for each item in the list.
typedef ItemBuilder<T> =
    Widget Function(BuildContext context, T item, int index);

/// Builder function for creating an error indicator widget.
typedef ErrorIndicatorBuilder =
    Widget Function(
      // ignore: avoid_positional_boolean_parameters
      BuildContext context,
      VoidCallback retryCallback,
      // ignore: avoid_positional_boolean_parameters
      bool isInitialError,
    );

/// Builder function for creating a loading or status indicator widget.
typedef IndicatorBuilder = Widget Function(BuildContext context);

/// A widget that provides slivers for an infinitely scrolling, paged list.
///
/// Designed to be used as a child of a [CustomScrollView]. It handles fetching
/// data in pages, displaying items, and showing status indicators (loading, error,
/// empty, no more items) as part of its sliver output.
class SliverInfinitePagedList<T> extends StatefulWidget {
  /// The function responsible for fetching a page of data.
  final FetchPageCallback<T> fetchPageCallback;

  /// A builder function to create a widget for each item in the list.
  /// These will be children of the internal [SliverList].
  final ItemBuilder<T> itemBuilder;

  /// The [ScrollController] of the parent [CustomScrollView]. This is required
  /// for detecting when to load more items.
  final ScrollController scrollController;

  /// The number of items to fetch per page.
  final int pageSize;

  /// The key for the first page to be fetched.
  final int firstPageKey;

  /// An optional builder for the widget to display when the list is initially loading.
  /// Rendered within a [SliverFillRemaining].
  final IndicatorBuilder? initialLoadingIndicatorBuilder;

  /// An optional builder for the widget to display as the last item in the [SliverList]
  /// when loading the next page.
  final IndicatorBuilder? nextPageLoadingIndicatorBuilder;

  /// An optional builder for the widget to display when an error occurs.
  /// It provides a `retryCallback` and `isInitialError` flag.
  /// For initial errors, rendered in [SliverFillRemaining]. For subsequent errors,
  /// it's the last item in the [SliverList].
  final ErrorIndicatorBuilder? errorIndicatorBuilder;

  /// An optional builder for the widget to display when the list is empty.
  /// Rendered within a [SliverFillRemaining].
  final IndicatorBuilder? emptyListIndicatorBuilder;

  /// An optional builder for the widget to display as the last item in the [SliverList]
  /// when all items have been fetched.
  final IndicatorBuilder? noMoreItemsIndicatorBuilder;

  /// An optional builder for a separator widget between items in the [SliverList].
  final IndexedWidgetBuilder? separatorBuilder;

  /// Optional padding for the [SliverList] containing the items.
  /// This padding is only applied when there are items to display, not for
  /// initial/empty/error states that use [SliverFillRemaining].
  final EdgeInsetsGeometry? sliverListPadding;

  /// A threshold (in pixels from the bottom) to trigger fetching the next page.
  final double scrollThreshold;

  /// PaginationController
  final PaginationController? paginationController;

  ///
  const SliverInfinitePagedList({
    required this.fetchPageCallback,
    required this.itemBuilder,
    required this.scrollController,
    super.key,
    this.pageSize = 20,
    this.firstPageKey = 0,
    this.initialLoadingIndicatorBuilder,
    this.nextPageLoadingIndicatorBuilder,
    this.errorIndicatorBuilder,
    this.emptyListIndicatorBuilder,
    this.noMoreItemsIndicatorBuilder,
    this.separatorBuilder,
    this.sliverListPadding,
    this.paginationController,
    this.scrollThreshold = 200.0,
  });

  @override
  State<SliverInfinitePagedList<T>> createState() =>
      _SliverInfinitePagedListState<T>();
}

class _SliverInfinitePagedListState<T>
    extends State<SliverInfinitePagedList<T>> {
  final List<T> _items = [];
  late int _currentPageKey;
  bool _isLoadingNextPage = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _hasMoreItems = true;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _currentPageKey = widget.firstPageKey;
    widget.scrollController.addListener(_onScroll);
    widget.paginationController?.addListener(_onPaginationController);
    _fetchFirstPage();
    widget.paginationController?.refresh = _refresh;
  }

  @override
  void didUpdateWidget(covariant SliverInfinitePagedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollController != oldWidget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      oldWidget.paginationController?.removeListener(_onPaginationController);
      widget.paginationController?.addListener(_onPaginationController);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    widget.scrollController.removeListener(_onScroll);
    widget.paginationController?.removeListener(_onPaginationController);
    super.dispose();
  }

  void _onPaginationController() {
    _isLoadingNextPage = false;
    _items.clear();
    _retry();
  }

  Future<void> _fetchFirstPage() async {
    if (_isDisposed) return;
    // Ensure not already loading (e.g. from a quick rebuild)
    if (_isLoadingNextPage && _items.isEmpty) return;

    setState(() {
      // Reset if it's truly a first page fetch (e.g. retry)
      // If _items is not empty, this is not a "first page" in terms of UI state.
      if (_items.isEmpty) {
        _isLoadingNextPage = true;
        _hasError = false;
        _errorMessage = null;
      }
    });
    await _fetchPageData(isInitialFetch: true);
  }

  Future<void> _refresh() async {
    if (_isDisposed) return;
    // Ensure not already loading (e.g. from a quick rebuild)
    if (_isLoadingNextPage && _items.isEmpty) return;

    setState(() {
      _hasError = false;
      _errorMessage = null;
      _currentPageKey = widget.firstPageKey;
    });
    await _fetchPageData(isInitialFetch: true, isRefresh: true);
  }

  Future<void> _fetchPageData({
    bool isInitialFetch = false,
    bool isRefresh = false,
  }) async {
    if (_isDisposed) return;

    // If it's not an initial fetch, set loading state for "next page"
    if (!isInitialFetch && _items.isNotEmpty) {
      // Check if already loading to prevent multiple simultaneous fetches
      if (_isLoadingNextPage) return;
      setState(() {
        _isLoadingNextPage = true;
        _hasError = false;
        _errorMessage = null;
      });
    } else if (isInitialFetch && _items.isEmpty) {
      // For initial fetch state setting
      if (!_isLoadingNextPage) {
        // If not already set by _fetchFirstPage
        setState(() {
          _isLoadingNextPage = true;
          _hasError = false;
          _errorMessage = null;
        });
      }
    }

    try {
      final newItems = await widget.fetchPageCallback(
        _currentPageKey,
        widget.pageSize,
      );
      if (_isDisposed) return;

      setState(() {
        if (isRefresh) {
          _items.clear();
        }
        _items.addAll(newItems);
        _currentPageKey++;
        _hasMoreItems = newItems.length == widget.pageSize;
        _isLoadingNextPage = false;
        _hasError = false;
      });
    } on InfiniteScrollListException catch (e, s) {
      if (_isDisposed) return;
      // ignore: avoid_print
      print('Error fetching page $_currentPageKey: $e\n$s');
      setState(() {
        _isLoadingNextPage = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    } on Exception catch (e, s) {
      if (_isDisposed) return;
      // ignore: avoid_print
      print('Error fetching page $_currentPageKey: $e\n$s');
      setState(() {
        _isLoadingNextPage = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients ||
        _isLoadingNextPage ||
        !_hasMoreItems ||
        _hasError) {
      return;
    }
    final maxScroll = widget.scrollController.position.maxScrollExtent;
    final currentScroll = widget.scrollController.position.pixels;

    if (maxScroll - currentScroll <= widget.scrollThreshold) {
      _fetchPageData();
    }
  }

  void _retry() {
    if (_items.isEmpty) {
      // Retrying initial load
      // Reset page key for a true retry of the first page logic
      _currentPageKey = widget.firstPageKey;
      _items.clear(); // Ensure items are clear for initial load state
      _hasMoreItems = true; // Assume there might be items on retry
      _fetchFirstPage();
    } else {
      // Retrying next page load
      _fetchPageData();
    }
  }

  // --- Default Builders ---
  Widget _defaultInitialLoadingIndicator(BuildContext context) =>
      const Center(child: CircularProgressIndicator.adaptive());
  Widget _defaultNextPageLoadingIndicator(BuildContext context) =>
      const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
  Widget _defaultEmptyListIndicator(BuildContext context) => const Center(
    child: Padding(padding: EdgeInsets.all(16), child: Text('No items found.')),
  );
  Widget _defaultNoMoreItemsIndicator(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text('You have reached the end of the list.'),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Case 1: Initial Loading
    if (_items.isEmpty && _isLoadingNextPage && !_hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child:
            widget.initialLoadingIndicatorBuilder?.call(context) ??
            _defaultInitialLoadingIndicator(context),
      );
    }

    // Case 2: Initial Error
    if (_items.isEmpty && _hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child:
            widget.errorIndicatorBuilder?.call(context, _retry, true) ??
            BeautifulErrorWidget(
              onRetry: _retry,
              isInitialError: true,
              errorMessage: _errorMessage,
            ),
      );
    }

    // Case 3: Empty List (after first successful fetch with no items)
    if (_items.isEmpty && !_hasMoreItems && !_isLoadingNextPage && !_hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child:
            widget.emptyListIndicatorBuilder?.call(context) ??
            _defaultEmptyListIndicator(context),
      );
    }

    // Case 4: List with items and/or status indicators at the end
    final actualItemCount = _items.length;

    // Calculate how many children the delegate will render for items and separators
    final delegateItemCount =
        widget.separatorBuilder != null && actualItemCount > 0
            ? (actualItemCount * 2 - 1)
            : actualItemCount;

    var finalChildCount = delegateItemCount;

    final showNextPageLoader = _isLoadingNextPage && actualItemCount > 0;
    final showNextPageError = _hasError && actualItemCount > 0;
    final showNoMoreItemsIndicator = !_hasMoreItems && actualItemCount > 0;

    if (showNextPageLoader || showNextPageError || showNoMoreItemsIndicator) {
      finalChildCount++;
    }

    final Widget sliverList = SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index < delegateItemCount) {
          // Item or separator
          if (widget.separatorBuilder != null) {
            final itemIndex = index ~/ 2;
            if (index.isEven) {
              // Actual item
              return widget.itemBuilder(context, _items[itemIndex], itemIndex);
            } else {
              // Separator
              return widget.separatorBuilder!(context, itemIndex);
            }
          } else {
            // No separators, so it's an actual item
            return widget.itemBuilder(context, _items[index], index);
          }
        } else {
          // Status indicator at the end
          if (showNextPageLoader) {
            return widget.nextPageLoadingIndicatorBuilder?.call(context) ??
                _defaultNextPageLoadingIndicator(context);
          }
          if (showNextPageError) {
            return widget.errorIndicatorBuilder?.call(context, _retry, false) ??
                BeautifulErrorWidget(
                  onRetry: _retry,
                  isInitialError: false,
                  errorMessage: _errorMessage,
                );
          }
          if (showNoMoreItemsIndicator) {
            return widget.noMoreItemsIndicatorBuilder?.call(context) ??
                _defaultNoMoreItemsIndicator(context);
          }
        }
        return null; // Should not happen if childCount is correct
      }, childCount: finalChildCount),
    );

    if (widget.sliverListPadding != null && actualItemCount > 0) {
      // Apply padding only if there are items, not to the full-page indicators
      return SliverPadding(
        padding: widget.sliverListPadding!,
        sliver: sliverList,
      );
    }
    return sliverList;
  }
}

/// A custom Exception class for handling errors in the SliverInfinitePagedList.
class InfiniteScrollListException implements Exception {
  /// The error message.
  final String message;

  /// Creates an instance of [InfiniteScrollListException].
  InfiniteScrollListException({required this.message});

  @override
  String toString() {
    return message;
  }
}

/// A controller for pagination.
///
/// This controller can be used to reset pagination state.
class PaginationController extends ChangeNotifier {
  bool _isDisposed = false;

  /// Indicates whether the controller is disposed.
  bool get isDisposed => _isDisposed;
  Timer? _timer;

  Future<void> Function()? refresh;

  /// Reset pagination state.
  void restart() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  Future<void> refreshPage() async {
    if (_isDisposed) {
      return;
    }
    await refresh?.call();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// A widget that displays an error message with a retry button.
class BeautifulErrorWidget extends StatelessWidget {
  ///
  final VoidCallback onRetry;

  ///
  final bool isInitialError;

  ///
  final String? errorMessage; // Optional detailed error message
  ///
  const BeautifulErrorWidget({
    required this.onRetry,
    required this.isInitialError,
    super.key,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24), // Increased padding around the card
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24), // Padding inside the card
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize:
                  MainAxisSize.min, // So the card doesn't take full height
              children: [
                Icon(
                  isInitialError
                      ? Icons.error_outline_rounded
                      : Icons.sync_problem_rounded,
                  color: colorScheme.error,
                  size: 64,
                ),
                const SizedBox(height: 20),
                Text(
                  isInitialError
                      ? 'Oops! Something went wrong.'
                      : 'Failed to load more.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isInitialError
                      ? "We couldn't load the items. Please check your connection and try again."
                      : "We couldn't fetch more items at this time. Please try again shortly.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (errorMessage != null && errorMessage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
