import { useLogout, useMenu, useNavigation } from "@refinedev/core";
import {
  Box,
  VStack,
  Button,
  Text,
  Divider,
} from "@chakra-ui/react";
import { IconDashboard, IconLogout } from "@tabler/icons-react";

export const Menu = () => {
  const { mutate: logout } = useLogout();
  const { menuItems } = useMenu();
  const { push } = useNavigation();

  return (
    <Box
      as="nav"
      width="250px"
      borderRight="1px solid"
      borderColor="gray.200"
      bg="gray.50"
      minHeight="100vh"
      p={4}
    >
      <Text fontSize="lg" fontWeight="bold" mb={6}>
        AiT SaaS Platform
      </Text>
      <VStack spacing={2} align="stretch">
        {menuItems.map((item) => (
          <Button
            key={item.key}
            variant="ghost"
            justifyContent="flex-start"
            leftIcon={<IconDashboard size={16} />}
            onClick={() => {
              if (item.route) {
                push(item.route);
              }
            }}
            colorScheme="blue"
          >
            {item.label}
          </Button>
        ))}
        <Divider my={4} />
        <Button
          variant="ghost"
          colorScheme="red"
          leftIcon={<IconLogout size={16} />}
          onClick={() => logout()}
          justifyContent="flex-start"
        >
          Logout
        </Button>
      </VStack>
    </Box>
  );
};
