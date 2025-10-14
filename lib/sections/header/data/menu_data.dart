// Top-level headers with Services as a grouped mega menu.
final List<Map<String, dynamic>> menuData = [
  {"title": "Home"}, // (1)
  {
    "title": "Services", // (2)
    "children": [
      {
        "title": "Business Setup", // (2.1)
        "children": [
          {"title": "Business Category / Track"}, // (2.1.1)
          {"title": "Business Manager / In-Charge"}, // (2.1.2)
          {"title": "Business Pitch / USP"}, // (2.1.3)
          {"title": "Business Onboarding"}, // (2.1.4)
          {"title": "Business Analysis"}, // (2.1.5)
          {"title": "Pain Points Identification"}, // (2.1.6)
          {"title": "Goal Setting"}, // (2.1.7)
        ]
      },
      {
        "title": "Branding", // (2.2)
        "children": [
          {"title": "Logo Design"}, // (2.2.1)
          {"title": "Business Cards"}, // (2.2.2)
          {"title": "Brochures"}, // (2.2.3)
          {"title": "Social Media Templates"}, // (2.2.4)
        ]
      },
      {
        "title": "Marketing", // (2.3)
        "children": [
          {"title": "Pamphlets"}, // (2.3.1)
          {"title": "Hoardings"}, // (2.3.2)
          {"title": "Reels"}, // (2.3.3)
          {"title": "Promotional Videos"}, // (2.3.4)
          {"title": "Google My Business (GMB)"}, // (2.3.5)
          {"title": "FB / Insta / YouTube / X / LinkedIn"}, // (2.3.6)
          {"title": "WhatsApp Marketing"}, // (2.3.7)
          {"title": "Google Ads"}, // (2.3.8)
        ]
      },
      {
        "title": "Websites", // (2.4)
        "children": [
          {"title": "Main Website"}, // (2.4.1)
          {"title": "Landing Pages"}, // (2.4.2)
          {"title": "Forms & Lead Capture"}, // (2.4.3)
        ]
      },
      {
        "title": "Software", // (2.5)
        "children": [
          {"title": "CRM Setup"}, // (2.5.1)
          {"title": "HR Management"}, // (2.5.2)
          {"title": "Accounts Management"}, // (2.5.3)
          {"title": "Inventory System"}, // (2.5.4)
          {"title": "Customer Service Tools"}, // (2.5.5)
        ]
      },
      {
        "title": "Automation", // (2.6)
        "children": [
          {"title": "WhatsApp Automation"}, // (2.6.1)
          {"title": "Email"}, // (2.6.2)
          {"title": "SMS"}, // (2.6.3)
          {"title": "Customer Journey Setup"}, // (2.6.4)
        ]
      },
      {
        "title": "Training", // (2.7)
        "children": [
          {"title": "CRM Usage"}, // (2.7.1)
          {"title": "Lead Management"}, // (2.7.2)
          {"title": "Follow-up Process"}, // (2.7.3)
          {"title": "Deal Closings"}, // (2.7.4)
        ]
      },
      {
        "title": "Growth", // (2.8)
        "children": [
          {"title": "Monthly Review"}, // (2.8.1)
          {"title": "Strategy Planning"}, // (2.8.2)
          {"title": "Sales Target Setting"}, // (2.8.3)
          {"title": "Expansion Planning"}, // (2.8.4)
        ]
      },
    ]
  },
  {
    "title": "Industries", // (3)
    "children": [
      {"title": "Retail"},
      {"title": "Education"},
      {"title": "Cosmetics"},
      {"title": "Printing & Packaging"},
      {"title": "Services (Industry)"},
      {"title": "Startup"},
    ]
  },
  {"title": "Pricing"}, // (4)
  {"title": "Portfolio"}, // (5)
  {
    "title": "Resources", // (6)
    "children": [
      {"title": "Blog"},
      {"title": "Guides"},
      {"title": "Templates"},
      {"title": "FAQs"},
    ]
  },
  {
    "title": "About", // (7) (landing removed; keep direct children to existing sub-pages)
    "children": [
      {"title": "Company"},
      {"title": "Team"},
      {"title": "Careers"},
    ]
  },
  {
    "title": "Contact", // (8)
    "children": [
      {"title": "Form"},
      {"title": "WhatsApp"},
      {"title": "Phone"},
    ]
  },
];
