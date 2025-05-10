

# Sliver Infinite Paged List

A Flutter package for creating infinitely scrolling, paged lists with customizable loading and error indicators.

## Overview

This package provides a `SliverInfinitePagedList` widget that can be used to create infinitely scrolling lists with pagination. It handles fetching data in pages, displaying items, and showing status indicators (loading, error, empty, no more items) as part of its sliver output.

## Features

* Infinitely scrolling list with pagination
* Customizable loading and error indicators
* Support for initial loading, error, and empty list states
* Automatic handling of scroll events to fetch next page
* Support for refreshing the list

## Usage

To use this package, add it to your `pubspec.yaml` file:

```yml
dependencies:
  sliver_infinite_paged_list: ^1.0.0
```

Then, import the package in your Dart file:

```dart
import 'package:sliver_infinite_paged_list/sliver_infinite_paged_list.dart';
```

Create a `SliverInfinitePagedList` widget and pass in the required parameters:

```dart
SliverInfinitePagedList(
  fetchPageCallback: (pageKey, pageSize) async {
    // Fetch data for the given page key and page size
    final data = await fetchData(pageKey, pageSize);
    return data;
  },
  pageSize: 10, // Number of items to fetch per page
  firstPageKey: 0, // Initial page key
  itemBuilder: (context, item, index) {
    // Build a widget for each item in the list
    return ListTile(title: Text(item.toString()));
  },
)
```

You can also customize the loading and error indicators by passing in custom builders:

```dart
SliverInfinitePagedList(
  // ...
  initialLoadingIndicatorBuilder: (context) {
    return Center(child: CircularProgressIndicator());
  },
  errorIndicatorBuilder: (context, retryCallback, isInitialError) {
    return Center(child: Text('Error occurred. Tap to retry.'));
  },
)
```

## Example

For a complete example, see the `example` directory in this package.

## API Documentation

See the [API documentation](https://pub.dev/documentation/sliver_infinite_paged_list/latest/sliver_infinite_paged_list/SliverInfinitePagedList-class.html) for more information on the available properties and methods.

## Changelog

See the [Changelog](https://pub.dev/packages/sliver_infinite_paged_list/changelog) for a list of changes and updates.

## License

This package is licensed under the [MIT License](https://opensource.org/licenses/MIT).

## Contributions

Contributions are welcome! If you have any issues or feature requests, please file an issue or submit a pull request.