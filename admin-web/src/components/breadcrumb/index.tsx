import { useBreadcrumb } from "@refinedev/core";
import { Box, Text, Link as ChakraLink } from "@chakra-ui/react";
import { Link } from "react-router";

export const Breadcrumb = () => {
  const { breadcrumbs } = useBreadcrumb();

  if (breadcrumbs.length === 0) {
    return null;
  }

  return (
    <Box p={4} borderBottom="1px solid" borderColor="gray.200" display="flex" gap={2} alignItems="center">
      {breadcrumbs.map((breadcrumb, index) => (
        <Box key={`breadcrumb-${breadcrumb.label}`} display="flex" alignItems="center" gap={2}>
          {breadcrumb.href && index < breadcrumbs.length - 1 ? (
            <ChakraLink as={Link} to={breadcrumb.href} color="blue.500">
              {breadcrumb.label}
            </ChakraLink>
          ) : (
            <Text fontWeight="medium">{breadcrumb.label}</Text>
          )}
          {index < breadcrumbs.length - 1 && <Text color="gray.400">/</Text>}
        </Box>
      ))}
    </Box>
  );
};
