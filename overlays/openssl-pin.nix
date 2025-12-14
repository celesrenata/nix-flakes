final: prev: {
  openssl = prev.openssl_3_6 or prev.openssl;
  openssl_3 = prev.openssl_3_6 or prev.openssl;
  openssl_3_4 = prev.openssl_3_6 or prev.openssl;
  openssl_3_5 = prev.openssl_3_6 or prev.openssl;
}
