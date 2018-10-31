/*
  Copyright:    © 2018 SIL International.
  Description:  Implementation of the context API functions using internal
                data structures and functions.
  Create Date:  27 Sep 2018
  Authors:      Tim Eves (TSE)
  History:      27 Sep 2018 - TSE - Initial implementation.
                5  Oct 2018 - TSE - Refactor out adaptor and internal classes
                                    into context.hpp
*/
#include <cassert>
#include <algorithm>
#include <iterator>
#include <vector>

#include <keyboardprocessor.h>

#include "context.hpp"
#include "json.hpp"
#include "utfcodec.hpp"

km_kbp_context::const_pointer km_kbp_context::data() const
{
  _pres.assign(begin(), end());
  _pres.emplace_back(km_kbp_context_item {KM_KBP_CT_END, {0,}, {0}});
  return _pres.data();
}


km_kbp_status
km_kbp_context_items_from_utf16(km_kbp_cp const *text,
                                km_kbp_context_item **out_ptr)
{
  *out_ptr = nullptr;
  std::vector<km_kbp_context_item> res;

  try
  {
    for (auto i = utf16::const_sentinal_iterator(text);
         i; ++i)
    {
      if(i.error())   return KM_KBP_STATUS_INVALID_ARGUMENT;
      res.emplace_back(km_kbp_context_item {KM_KBP_CT_CHAR, {0,}, {*i}});
    }
    res.emplace_back(km_kbp_context_item {KM_KBP_CT_END, {0,}, {0}});
    *out_ptr = new km_kbp_context_item[res.size()];
    std::copy(res.begin(), res.end(), *out_ptr);
  }
  catch(std::bad_alloc)
  {
    return KM_KBP_STATUS_NO_MEM;
  }

  return KM_KBP_STATUS_OK;
}


size_t km_kbp_context_items_to_utf16(km_kbp_context_item const *ci,
                                     km_kbp_cp *buf, size_t buf_size)
{
  assert(ci != nullptr);
  if (!ci) return 0;

  if (buf && buf_size > 0)
  {
    auto i = utf16::iterator(buf);
    auto const e = utf16::iterator(buf + buf_size - 1);
    for (;i != e && ci->type != KM_KBP_CT_END; ++ci)
    {
      if (ci->type == KM_KBP_CT_CHAR)
      {
        *i = ci->character; ++i;
      }
    }
    *i = 0;
    return buf_size - (e - i);
  }
  else
  {
    auto n = 0;

    do
      if (ci->type == KM_KBP_CT_CHAR)
        ++n += int(ci->character >= 0x10000);
    while(ci++->type != KM_KBP_CT_END);
    return n+1;
  }
}


void km_kbp_context_items_dispose(km_kbp_context_item *ci)
{
  delete [] ci;
}


km_kbp_status km_kbp_context_set(km_kbp_context *ctxt, km_kbp_context_item const *ci)
{
    ctxt->clear();
    return km_kbp_context_append(ctxt, ci);
}


km_kbp_context_item const * km_kbp_context_get(km_kbp_context const *ctxt)
{
  return ctxt->data();
}


void km_kbp_context_clear(km_kbp_context *ctxt)
{
  ctxt->clear();
}


size_t km_kbp_context_length(km_kbp_context *ctxt)
{
  return ctxt->size();
}


km_kbp_status km_kbp_context_append(km_kbp_context *ctxt,
                                    km_kbp_context_item const *ci)
{
  try
  {
    while(ci->type != KM_KBP_CT_END) ctxt->emplace_back(*ci++);
  } catch(std::bad_alloc) {
    return KM_KBP_STATUS_NO_MEM;
  }

  return KM_KBP_STATUS_OK;
}


km_kbp_status km_kbp_context_shrink(km_kbp_context *ctxt, size_t num,
                           km_kbp_context_item const * ci)
{
  try
  {
    ctxt->resize(ctxt->size() - std::min(num, ctxt->size()));

    if (ci)
    {
      auto const ip = ctxt->begin();
      while(num-- && ci->type != KM_KBP_CT_END)
        ctxt->emplace(ip, *ci++);
    }
  } catch(std::bad_alloc) {
    return KM_KBP_STATUS_NO_MEM;
  }

  return KM_KBP_STATUS_OK;
}


json & operator << (json & j, km::kbp::context const & ctxt) {
  j << json::array;
  for (auto & i: ctxt)  j << i;
  return j << json::close;
}

json & operator << (json & j, km_kbp_context_item const & i)
{
  utf8::codeunit_t cps[5] = {0,};
  int8_t l;

  switch (i.type)
  {
    case KM_KBP_CT_CHAR:
      utf8::codec::put(cps, i.character, l);
      j << &cps[0];
      break;
    case KM_KBP_CT_MARKER:
      j << i.marker;
      break;
    default:
      j << json::flat << json::object
          << "invalid type" << i.type
          << json::close;
  }
  return j;
}