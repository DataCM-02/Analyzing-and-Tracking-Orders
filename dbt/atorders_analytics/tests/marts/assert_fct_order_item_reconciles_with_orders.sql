with item_totals as (

    select
        order_id,
        sum(gross_line_amount) as item_subtotal_amount,
        sum(discount_amount) as item_discount_amount,
        sum(net_line_amount) as item_net_amount

    from {{ ref('fct_order_item') }}

    group by order_id

)

select
    o.order_id,
    o.subtotal_amount,
    i.item_subtotal_amount,
    o.discount_amount,
    i.item_discount_amount,
    o.net_merchandise_amount,
    i.item_net_amount

from {{ ref('fct_order') }} as o
left join item_totals as i
    on o.order_id = i.order_id

where i.order_id is null
   or o.subtotal_amount <> i.item_subtotal_amount
   or o.discount_amount <> i.item_discount_amount
   or o.net_merchandise_amount <> i.item_net_amount