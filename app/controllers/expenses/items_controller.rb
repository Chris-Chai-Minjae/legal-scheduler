module Expenses
  class ItemsController < ApplicationController
    before_action :require_authentication
    layout "dashboard"

    def index
      @expenses = Current.session.user.expenses.by_date

      if params[:card_name].present?
        @expenses = @expenses.by_card(params[:card_name])
      end

      if params[:category].present?
        @expenses = @expenses.by_category(params[:category])
      end

      if params[:date_from].present?
        @expenses = @expenses.where("transaction_date >= ?", params[:date_from])
      end

      if params[:date_to].present?
        @expenses = @expenses.where("transaction_date <= ?", params[:date_to])
      end

      @card_names = Current.session.user.expenses.distinct.pluck(:card_name).compact
      @categories = Current.session.user.expenses.classified.distinct.pluck(:category).compact
    end

    def show
      @expense = Current.session.user.expenses.find(params[:id])
    end

    def edit
      @expense = Current.session.user.expenses.find(params[:id])
    end

    def update
      @expense = Current.session.user.expenses.find(params[:id])

      if @expense.update(expense_params.merge(
        classification_status: :manual,
        description: ExpenseClassifierService.format_description(
          expense_params[:memo] || @expense.memo, @expense.merchant, @expense.card_name
        )
      ))

        redirect_to expenses_items_path, notice: "경비가 수정되었습니다."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def expense_params
      params.require(:expense).permit(:category, :memo)
    end
  end
end
