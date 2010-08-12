#define qLog(s, ...) superLog(__FILE__, __LINE__, (char *)__FUNCTION__, (s),##__VA_ARGS__)

void superLog(char *sourceFile, int lineNumber, char *functionName, id format, ...);