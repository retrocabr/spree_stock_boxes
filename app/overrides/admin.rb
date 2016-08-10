# coding: utf-8

Deface::Override.new(:virtual_path => "spree/admin/shared/sub_menu/_configuration",
                     :name => "add_stock_boxes_settings",
                     :insert_bottom => "[data-hook='admin_configurations_sidebar_menu'], #admin_configurations_sidebar_menu[data-hook]",
                     :text => "<%= configurations_sidebar_menu_item('Configurações do estoque', admin_stock_boxes_url) %>")

Deface::Override.new(:virtual_path => "spree/admin/shared/sub_menu/_product",
                     :name => "add_stocking_settings",
                     :insert_bottom => "ul#sidebar-product",
                     :text => "<li class='sidebar-menu-item'><%= link_to 'Stocking', admin_stocking_url %></li>")

Deface::Override.new(:virtual_path => 'spree/admin/products/_form',
                     :name => 'insert_product_box',
                     :insert_before => 'ul#shipping_specs',
                     :text => '<li id="shipping_specs_dimensions_field" class="field alpha four columns">
                               <%= f.label :stock_box_number, "Caixa do estoque" %>
                               <%= f.text_field :stock_box_number, :size => 8 %></li>')