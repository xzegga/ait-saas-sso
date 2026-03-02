# Email Templates System

## Overview

Complete email template management system that allows:
- Generic templates (for all products)
- Product-specific templates (override generic ones)
- Management from the admin panel
- Configurable placeholders
- Real-time preview

## Database Structure

### `email_templates` Table

```sql
CREATE TABLE public.email_templates (
  id uuid PRIMARY KEY,
  name text NOT NULL, -- Template identifier
  product_id uuid REFERENCES products(id), -- NULL = generic, NOT NULL = product-specific
  subject text NOT NULL,
  body_html text NOT NULL,
  body_text text, -- Optional plain text version
  placeholders jsonb, -- Array of available placeholders
  description text,
  is_active boolean DEFAULT true,
  created_at timestamptz,
  updated_at timestamptz,
  created_by uuid,
  updated_by uuid,
  deleted_at timestamptz, -- Soft delete
  UNIQUE (name, product_id)
);
```

### Template Types

1. **user_signup_confirmation**: User registration confirmation
   - Placeholders: `user_name`, `user_email`, `product_name`, `verification_link`

2. **password_reset**: Password recovery
   - Placeholders: `user_name`, `user_email`, `product_name`, `reset_link`

3. **user_invitation**: Registration invitation
   - Placeholders: `inviter_name`, `inviter_email`, `product_name`, `organization_name`, `invitation_link`, `user_role`

4. **admin_new_user_notification**: Admin notification for new user
   - Placeholders: `user_name`, `user_email`, `product_name`, `registration_date`

## Database Functions

### `get_email_template(p_template_name, p_product_id)`

Retrieves a template, prioritizing product-specific over generic:

```sql
SELECT * FROM public.get_email_template('user_signup_confirmation', 'product-uuid');
-- Returns product-specific template if exists, otherwise generic one
```

### `render_email_template(p_template_name, p_product_id, p_placeholders)`

Renders a template by replacing placeholders:

```sql
SELECT * FROM public.render_email_template(
  'user_signup_confirmation',
  'product-uuid',
  '{"user_name": "John", "verification_link": "https://..."}'::jsonb
);
-- Returns: subject, body_html, body_text with placeholders replaced
```

## Administration Interface

### List Page (`/email-templates`)

- Lists all templates (generic and product-specific)
- Filters by template type and product
- Search by subject, description, or product
- Actions: Edit, Duplicate

### Edit/Create Page (`/email-templates/create`, `/email-templates/edit/:id`)

- Template editor with:
  - Template type selector
  - Product selector (optional, for product-specific templates)
  - Subject editor
  - HTML and plain text editors (tabs)
  - List of available placeholders (click to insert)
  - Real-time preview with sample data
  - Active/inactive toggle

## Usage Flow

### 1. Create Generic Template

1. Go to `/email-templates`
2. Click "Create Generic Template"
3. Select template type
4. Leave "Product" empty (generic)
5. Configure subject and body with placeholders
6. Save

### 2. Create Product-Specific Template

1. Go to `/email-templates`
2. Click "Create Generic Template" (or duplicate an existing one)
3. Select template type
4. Select specific product
5. Customize subject and body
6. Save

### 3. Duplicate Template

1. In the list, click the duplicate button (Copy icon)
2. Editor opens with original template data
3. Modify as needed
4. Save (creates new template)

## Template Resolution Logic

When sending an email:

1. Search for product-specific template (`product_id = X`)
2. If not found, use generic template (`product_id IS NULL`)
3. Render with provided placeholders
4. Send email

## Common Placeholders

| Placeholder | Description | Available in |
|------------|-------------|---------------|
| `user_name` | User's name | All |
| `user_email` | User's email | All |
| `product_name` | Product name | All |
| `verification_link` | Verification link | Signup confirmation |
| `reset_link` | Password reset link | Password reset |
| `invitation_link` | Invitation link | User invitation |
| `inviter_name` | Inviter's name | User invitation |
| `inviter_email` | Inviter's email | User invitation |
| `organization_name` | Organization name | User invitation |
| `user_role` | User role | User invitation |
| `registration_date` | Registration date | Admin notification |

## Security

- Only super admins can create/edit/delete templates
- Authenticated and anonymous users can read active templates (needed for sending emails)
- RLS policies implemented

## Next Steps

1. Implement email sending using these templates
2. Integrate with Edge Functions for sending via Resend
3. Add more template types as needed
4. Add template change history
5. Add template versioning
