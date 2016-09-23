# coding: utf-8
require 'barby'
require 'barby/barcode/code_128'
require 'barby/outputter/png_outputter'

module Spree
  module Admin
    class StockBoxesController < ResourceController #Spree::Admin::BaseController

      # GET /stock_boxes
      # GET /stock_boxes.json
      def index
        params[:order_by] ||= "name"
        per_page = 20
        params[:page] ||= "1"

        @stock_boxes = case params[:order_by]
          when "nonempty"
            StockBox.where("quantity > ?", 0).order(:number).page(params[:page]).per(per_page)
          when "quantity"
            Kaminari.paginate_array(StockBox.all.sort_by{ |b| b.total_items }.reverse).page(params[:page]).per(per_page)
          else
            StockBox.order(:number).page(params[:page]).per(per_page)
        end

        respond_to do |format|
          format.html # index.html.erb
          format.json { render json: @stock_boxes }
        end
      end

      # GET /stock_boxes/1
      # GET /stock_boxes/1.json
      def show
        @stock_box = StockBox.find(params[:id])
        stock_state_priority = ["Estoque","Reservado","Perdido","Vendido"].reverse
        @variants = @stock_box.variants#.sort_by { |v| [v.count_on_hand, stock_state_priority.index(v.stock_state)] }.reverse
        @variant_names = []
        @variants.each do |variant|
          @variant_names.push(variant.name)
        end

        @barcode_path = "/tmp/barcode_stockbox_#{@stock_box.number}.png"
        unless FileTest.exist?("#{Rails.root}/public#{@barcode_path}")
          barcode = Barby::Code128A.new(@stock_box.number)
          File.open("#{Rails.root}/public#{@barcode_path}", 'w+') do |f|
            f.write barcode.to_png(:margin => 3, :xdim => 2, :height => 65)
          end
        end

        if params[:print]
          respond_to do |format|
            format.html { render action: "show", layout: "spree/layouts/blank" }
          end
        else
          respond_to do |format|
            format.html # show.html.erb
            format.json { render json: { stock_box: @stock_box, variants: @variants, variant_names: @variant_names } }
          end
        end
      end

      # GET /stock_boxes/new
      # GET /stock_boxes/new.json
      def new
        @stock_box = StockBox.new

        respond_to do |format|
          format.html # new.html.erb
          format.json { render json: @stock_box }
        end
      end

      # GET /stock_boxes/1/edit
      def edit
        @stock_box = StockBox.find(params[:id])
      end

      # POST /stock_boxes
      # POST /stock_boxes.json
      def create
        @stock_box = Spree::StockBox.new(stock_box_params)
        @stock_box.quantity = 1 unless @stock_box.quantity

        respond_to do |format|
          if @stock_box.save
            format.html { redirect_to admin_stock_boxes_url, notice: 'Caixa de estoque criada com sucesso.' }
            format.json { render json: @stock_box, status: :created, location: @stock_box }
          else
            format.html { render action: "new" }
            format.json { render json: @stock_box.errors, status: :unprocessable_entity }
          end
        end
      end

      # PUT /stock_boxes/1
      # PUT /stock_boxes/1.json
      def update
        @stock_box = StockBox.find(params[:id])

        respond_to do |format|
          if @stock_box.update_attributes(params[:stock_box])
            format.html { redirect_to admin_stock_boxes_url, notice: 'Caixa de estoque atualizada com sucesso.' }
            format.json { head :no_content }
          else
            format.html { render action: "edit" }
            format.json { render json: @stock_box.errors, status: :unprocessable_entity }
          end
        end
      end

      # DELETE /stock_boxes/1
      # DELETE /stock_boxes/1.json
      def destroy
        @stock_box = StockBox.find(params[:id])
        @stock_box.destroy

        respond_to do |format|
          format.html { redirect_to admin_stock_boxes_url }
          format.json { head :no_content }
        end
      end

      def stocking

      end

      def stocking_check
        @box = Spree::StockBox.find_by_number(params[:box_number])
        if params[:field_action] == "open"

          if @box
            task = Spree::Task.where(name: "Stocking").first
            effort = @box.efforts.where(task_id: task.id).first_or_create
         
            effort.started_at ||= Time.now
            effort.user_id ||= spree_current_user.id
            effort.object_id ||= @box.id
            effort.object_type ||= "Spree::StockBox"
            effort.description ||= "Estocando produtos na caixa #{params[:box_number]}"
            effort.save


          end

          check = "open"
          @start_at = DateTime.now
          respond_to do |format|
            format.js { render "box_open" }
          end
        end

        if params[:field_action] == "insert"
          check = "insert"

          @new_image = nil
          registered_items = params[:registered_items]

          new_item = params[:stock_items].split(",").last.squish.downcase
          @last_entry = new_item
          box_number = params[:box_number].downcase

          @new_value = registered_items
          if new_item == box_number
            respond_to do |format|
              format.js { render "box_close" }
            end
          elsif new_item.to_i > 10000000000 and new_item.to_i < 20000000000 and new_item.to_i.to_s == new_item

            variant = Spree::Variant.find_by_sku(new_item)
            if variant
              @check_message = 2
              if variant.count_on_hand == 0
                @check_message = 4
                order = variant.product.order
                shipment = order ? order.shipments.last : nil
                if shipment
                  @check_message = 1 if shipment.state == "shipped" || shipment.state == "ready"
                end
              end
            else
              name = "Produto em processo de cadastramento"
              p = Spree::Product.new(sku: new_item, price: 0, name: name, permalink: name.parameterize)
              p.save(validate: false)
              @check_message = 3
            end

            if @check_message > 1
              new_value = [registered_items, new_item, ", "] - [""]
              @new_value = new_value.join("") if new_value
            end

            product = variant.product if variant
            images = product.images if product
            if images && !images.empty?
              attachment = images.first.attachment
              @new_image = attachment.url(:product) if attachment
            end

            respond_to do |format|
              format.js { render "box_insert" }
            end
          else
            @old_value = registered_items
            respond_to do |format|
              format.js { render "box_insert_error" }
            end
          end
        end

        if params[:field_action] == "close"
          check = "close"

          if @box
            task = Spree::Task.where(name: "Stocking").first
            effort = @box.efforts.where(task_id: task.id).first_or_create
         
            effort.completed_at ||= Time.now
            effort.user_id ||= spree_current_user.id
            effort.object_id ||= @box.id
            effort.object_type ||= "Spree::StockBox"
            effort.quantity = params[:registered_items].split(',').size -1
            effort.save


          end


          registerer_id = spree_current_user.id
          total_registered_items = 0

          registered_items = params[:registered_items]
          registered_items.split(", ").each do |v|
            variant = Spree::Variant.find_by_sku(v)
            variant.update_column(:stock_box_id, @box.id)
            variant.update_column(:stocked_by_id, registerer_id)
            total_registered_items += 1
          end

          # start_at = params[:effort_starts_at]
          # end_at = DateTime.now
          # activity = Spree::Activity.find_by_name("Estoque")
          # task = Spree::Task.where(name:"Stocking").where(activity_id:activity.id).first
          # effort = Spree::Effort.new(description: "Estocando produtos na caixa #{@box.number}", started_at: start_at)
          # effort.user_id = registerer_id
          # effort.task_id = task.id
          # effort.object_id = @box.id
          # effort.object_type = "Spree::StockBox"
          # effort.quantity = total_registered_items
          # effort.completed_at = end_at
          # effort.save

          respond_to do |format|
            format.js { render "page_reload" }
          end

        end

        render nothing: true unless check
      end

      private

      def stock_box_params
        params.require(:stock_box).permit(:number, :last_check_at, :positionX, :positionY, :positionZ, :quantity)
      end
    end
  end
end
