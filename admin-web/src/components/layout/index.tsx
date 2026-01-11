import type { PropsWithChildren } from "react";
import { Box, Flex } from "@chakra-ui/react";
import { Menu } from "../menu";
import { Breadcrumb } from "../breadcrumb";

export const Layout: React.FC<PropsWithChildren> = ({ children }) => {
  return (
    <Flex minHeight="100vh">
      <Menu />
      <Box flex={1} display="flex" flexDirection="column">
        <Breadcrumb />
        <Box flex={1} p={4}>
          {children}
        </Box>
      </Box>
    </Flex>
  );
};
