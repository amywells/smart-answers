# encoding: UTF-8
require_relative '../../test_helper'
require_relative 'flow_test_helper'

class CalculateStatutorySickPayTest < ActiveSupport::TestCase
  include FlowTestHelper
  setup do
    setup_for_testing_flow 'calculate-statutory-sick-pay-v2'
  end

  context "Already getting maternity allowance" do
    context "Getting statutory maternity pay" do
      should "take them to outcome 1" do
        add_response "statutory_maternity_pay"
        assert_current_node :already_getting_maternity
      end
    end

    context "Getting maternity allowance" do
      should "take them to outcome 1" do
        add_response "maternity_allowance"
        assert_current_node :already_getting_maternity
      end
    end
    context "Not getting maternity allowance" do
      setup do
        add_response "ordinary_statutory_paternity_pay"
      end

      should "take the user to Q2" do
        assert_current_node :employee_tell_within_limit?
      end

      context "employee didn't tell employer within time limit" do
        should "take them to answer 3" do
          add_response :no
          assert_current_node :didnt_tell_soon_enough
        end
      end

      context "employee told employer within time limit" do
        setup do
          add_response :yes
        end

        should "take them to Q3" do
          assert_current_node :employee_work_different_days?
        end

        context "employee works regular days" do
          setup do
            add_response :no
          end

          should "take them to Q4" do
            assert_current_node :first_sick_day?
          end

          context "answering first sick day" do
            setup do
              add_response "02/04/2012"
            end

            should "store response and move to Q5" do
              assert_state_variable :sick_start_date, " 2 April 2012"
              assert_current_node :last_sick_day?
            end

            context "answering last sick day" do
              context "last sick day is 3 days or more after first" do
                setup do
                  add_response "10/04/2012"
                end

                should "store last sick day" do
                  assert_state_variable :sick_end_date, "10 April 2012"
                end

                should "take user to Q6" do
                  assert_current_node :last_payday_before_sickness?
                end

                context "last pay day before sickness" do
                  context "enter date after sick start" do
                    setup do
                      add_response "11/04/2012"
                    end

                    should "raise error" do
                      assert_current_node :last_payday_before_sickness?
                      assert_current_node_is_error
                    end
                  end

                  context "enter date before sick start" do
                    setup do
                      add_response "01/04/2012"
                    end

                    should "store this date" do
                      assert_state_variable :relevant_period_to, " 1 April 2012"
                    end

                    should "store the offset as 8 weeks earlier" do
                      assert_state_variable :pay_day_offset, " 5 February 2012"
                    end

                    should "take user to next Q" do
                      assert_current_node :last_payday_before_offset?
                    end

                    context "answering Q7" do
                      context "Answering with valid date" do
                        setup do
                          add_response "01/02/2012"
                        end

                        should "calculate the relevant period as response + 1 day" do
                          assert_state_variable :relevant_period_from, " 2 February 2012"
                        end

                        should "take user to Q8" do
                          assert_current_node :how_often_pay_employee?
                        end

                        context "Answering Q8" do
                          context "answering with pay monthly" do
                            setup do
                              add_response :monthly
                            end

                            should "calculate the monthly_pattern_payments" do
                              assert_state_variable :monthly_pattern_payments, 2
                              assert_current_node :on_start_date_8_weeks_paid?
                            end
                          end # answering Q8 pay monthly

                          context "Answering with weekly" do
                            should "take user to Q9" do
                              add_response :weekly
                              assert_current_node :on_start_date_8_weeks_paid?
                            end
                          end # answering Q8 weekly

                          context "Answering Q9" do
                            setup do
                              add_response :monthly
                            end

                            should "take them to Q10 if they answer yes" do
                              add_response :yes
                              assert_current_node :total_employee_earnings?
                            end

                            should "take them to Q11 if they answer no" do
                              add_response :no
                              assert_current_node :employee_average_earnings?
                            end

                            context "Answering Q10" do
                              setup do
                                add_response :yes
                                add_response "100"
                              end

                              should "calculate the AWE" do
                                assert_state_variable :relevant_period_awe, 11.538461538461538
                              end

                              should "take them to Answer 5 if value < LEL" do
                                assert_current_node :not_earned_enough
                              end
                            end
                          end # Answering Q9
                        end # Answering Q8
                      end

                      context "Answering with invalid date" do
                        should "raise error" do
                          add_response "04/05/2012"
                          assert_current_node_is_error
                        end

                      end # Answering Q8 with invalid date

                    end # last payday before offset Q7
                  end
                end # last pay day before sickness Q6
              end # last sick day Q5

              context "last sick day is <3 days after first" do
                should "take user to A2" do
                  add_response "03/04/2012"
                  assert_current_node :must_be_sick_for_4_days
                end
              end

              context "last day is before first day (invalid)" do
                should "raise error" do
                  add_response "01/04/2012"
                  assert_current_node_is_error
                end
              end

            end
          end

        end

        context "employee works weird days" do
          should "take them to A4" do
            add_response :yes
            assert_current_node :not_regular_schedule
          end
        end
      end

    end
  end
end
