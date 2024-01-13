import type { Config } from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import { prismTheme } from './prism';

const organizationName = "antonbashir";
const projectName = "dart-iouring-transport";
const baseUrl = `/${projectName}/`;

const config: Config = {
  title: 'Dart IOUring Transport',
  tagline: 'Dart IOUring Transport',
  favicon: 'images/favicon.png',
  url: `https://${organizationName}.github.io`,
  baseUrl,
  organizationName,
  projectName,
  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },
  themes: [
    [require.resolve("@easyops-cn/docusaurus-search-local"),
    ({
      indexBlog: false,
      docsRouteBasePath: '/',
      hashed: true,
    })
    ]
  ],
  presets: [
    [
      'classic',
      {
        docs: {
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
        },
        pages: false,
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    colorMode: {
      defaultMode: 'dark',
      disableSwitch: true,
      respectPrefersColorScheme: false,
    },
    navbar: {
      title: 'Dart IOUring Transport',
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'documentationSidebars',
          position: 'left',
          label: '📃 Documentation',
        },
        {
          href: 'https://antonbashir.github.io',
          label: '👤 Author',
          position: 'left',
        },
        {
          href: 'https://antonbashir.github.io/projects',
          label: '💼 Projects',
          position: 'left',
        },
        {
          href: 'https://github.com/antonbashir/dart-iouring-transport',
          "aria-label": "Source",
          position: 'right',
          className: "header-github-link",
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          label: 'Author',
          href: 'https://antonbashir.github.io',
        },
        {
          label: 'Telegram',
          href: 'https://t.me/antonbashir',
        },
        {
          label: 'Linkedin',
          href: 'https://www.linkedin.com/in/anton-bashirov',
        },
        {
          label: 'Dart',
          href: 'https://dart.dev/',
        },
        {
          label: 'Flutter',
          href: 'https://flutter.dev/',
        },
        {
          label: 'io_uring',
          href: 'https://github.com/espoal/awesome-iouring',
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} ${organizationName}`,
    },
    prism: {
      darkTheme: prismTheme,
      additionalLanguages: ['dart', 'yaml',]
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
