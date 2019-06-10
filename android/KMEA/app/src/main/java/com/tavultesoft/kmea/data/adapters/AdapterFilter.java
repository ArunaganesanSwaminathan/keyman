package com.tavultesoft.kmea.data.adapters;

import android.widget.ArrayAdapter;

import java.util.List;

/**
 * Used by NestedAdapters to selectively filter which elements are selected from the original Adapter.
 * @param <Element> The type of both Adapters' elements.
 */
public interface AdapterFilter<Element, Adapter extends ArrayAdapter<Element>> {
  /**
   * Filters the specified adapter for matching elements.
   * @param adapter An existing adapter with elements, some of which should be excluded by this filter.
   * @return A List of all elements of the adapter that match the filter's conditions.
   */
  List<Element> selectFrom(Adapter adapter);
}
