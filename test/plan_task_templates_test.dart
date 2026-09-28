import 'package:flutter_test/flutter_test.dart';
import 'package:tulasisolutionssite/core/constants/enums.dart';
import 'package:tulasisolutionssite/core/models/models.dart';
import 'package:tulasisolutionssite/core/widgets/feature_progress_widgets.dart';

PlanTemplate template({
  required String id,
  required List<TemplateTask> tasks,
}) => PlanTemplate(
  id: id,
  type: PlanType.setup,
  name: 'Standard Setup',
  price: 1000,
  features: tasks
      .map((task) => encodePlanTaskFeature(task.category, task.title))
      .toList(),
  tasks: tasks,
  createdDate: DateTime(2024, 1, 1),
);

Plan emptyPlan() => Plan(
  id: 'plan-1',
  clientId: 'client-1',
  type: PlanType.setup,
  name: 'Starter',
  price: 0,
  features: const [],
  startDate: DateTime(2024, 1, 1),
);

void main() {
  group('plan task templates', () {
    test('uses the consolidated task categories for all plan types', () {
      expect(visionAndPlanFeatureCategory, 'Vision & Plan');
      expect(softwareFeatureCategory, 'Software');
      expect(contentFeatureCategory, 'Content');
      expect(marketingFeatureCategory, 'Marketing');
      expect(distributionFeatureCategory, 'Distribution');
      expect(allPlanFeatureCategories, [
        visionAndPlanFeatureCategory,
        softwareFeatureCategory,
        contentFeatureCategory,
        marketingFeatureCategory,
        distributionFeatureCategory,
      ]);
      expect(planFeatureSubcategories[softwareFeatureCategory], ['App', 'Web']);
      expect(planFeatureSubcategories[contentFeatureCategory], [
        'Brand Kit',
        'Video Kit',
        'Content',
      ]);
      expect(planFeatureSubcategories[marketingFeatureCategory], [
        'Set up',
        'Manage',
      ]);
      expect(planFeatureSubcategories[distributionFeatureCategory], [
        'Set up',
        'Manage',
      ]);
      expect(setupPlanFeatureCategories, allPlanFeatureCategoryLabels);
      expect(subscriptionPlanFeatureCategories, allPlanFeatureCategoryLabels);
      expect(customTaskFeatureCategories, allPlanFeatureCategories);
    });

    test('displays legacy task categories under the consolidated names', () {
      expect(displayFeatureCategory('Goals'), visionAndPlanFeatureCategory);
      expect(displayFeatureCategory('Promise'), visionAndPlanFeatureCategory);
      expect(displayFeatureCategory('Website & App'), 'Software / Web');
      expect(displayFeatureCategory('Software'), 'Software / Web');
      expect(displayFeatureCategory('Practice'), 'Content / Brand Kit');
      expect(displayFeatureCategory('Design'), 'Content / Brand Kit');
      expect(displayFeatureCategory('Content'), 'Content / Content');
      expect(
        displayFeatureCategory('Distribution'),
        'Distribution / Set up',
      );
      expect(displayFeatureCategory('Support'), 'Distribution / Set up');
      expect(parseFeatureCategory('Software / App').category, 'Software');
      expect(parseFeatureCategory('Software / App').subcategory, 'App');
    });

    test(
      'assignment copies template tasks into an independent client snapshot',
      () {
        final original = template(
          id: 'standard',
          tasks: const [
            TemplateTask(
              id: 'logo',
              category: 'Design',
              title: 'You get a logo',
              defaultInstructions: 'Use the approved brief.',
              order: 1,
            ),
          ],
        );

        final assigned = emptyPlan().withTemplateTasks(original);
        final editedTemplate = template(
          id: 'standard',
          tasks: const [
            TemplateTask(
              id: 'logo',
              category: 'Design',
              title: 'A different logo task',
              order: 1,
            ),
          ],
        );

        expect(assigned.tasks.single.title, 'You get a logo');
        expect(assigned.tasks.single.instructions, 'Use the approved brief.');
        expect(editedTemplate.tasks.single.title, 'A different logo task');
        expect(assigned.tasks.single.templateTaskId, 'logo');
      },
    );

    test(
      'plan change adds only template titles that are not already present',
      () {
        final existing = emptyPlan()
            .withTemplateTasks(
              template(
                id: 'basic',
                tasks: const [
                  TemplateTask(
                    id: 'logo',
                    category: 'Design',
                    title: 'Logo',
                    order: 1,
                  ),
                ],
              ),
            )
            .copyWith(
              tasks: const [
                ClientTask(
                  id: 'logo',
                  category: 'Design',
                  title: 'Logo',
                  order: 1,
                  source: ClientTaskSource.template,
                  templateTaskId: 'logo',
                ),
                ClientTask(
                  id: 'extra',
                  category: 'Content',
                  title: 'Extra social platform',
                  order: 2,
                  source: ClientTaskSource.customBillable,
                  addedReason: 'Client requested it.',
                ),
              ],
            );
        final changed = existing.mergeTemplateTasks(
          template(
            id: 'standard',
            tasks: const [
              TemplateTask(
                id: 'logo-v2',
                category: 'Design',
                title: 'Logo',
                order: 1,
              ),
              TemplateTask(
                id: 'app',
                category: 'Website & App',
                title: 'Mobile app',
                order: 2,
              ),
            ],
          ),
        );

        expect(changed.tasks.map((task) => task.title), [
          'Logo',
          'Extra social platform',
          'Mobile app',
        ]);
        expect(changed.tasks[1].source, ClientTaskSource.customBillable);
        expect(changed.templateId, 'standard');
      },
    );
  });
}
