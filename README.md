<div align="center">

# TrueOG Network

[![discord-plural](https://cdn.jsdelivr.net/npm/@intergrav/devins-badges@3/assets/cozy/social/discord-plural_vector.svg)](https://discord.gg/ma9pMYpBU6)
<a href="https://store.trueog.net/"><img alt="donate-button" src="https://cdn.jsdelivr.net/npm/@intergrav/devins-badges@3/assets/cozy/donate/generic-plural_vector.svg"></a>
<a href="https://github.com/PurpurMC/Purpur"><img alt="purpur" height="56" src="https://cdn.jsdelivr.net/npm/@intergrav/devins-badges@3/assets/cozy/supported/purpur_vector.svg"></a>
[![NoSystemD](https://git.trueog.net/trueog/website/raw/branch/main/assets/images/logos/nossytemd.svg)](https://nosystemd.org/)

![Icon](https://git.trueog.net/trueog/website/raw/branch/main/assets/images/logos/Logo-Alternate-Transparent.png)

</div>

TrueOG Network is a 100% free and open source community-oriented Minecraft server. Inspired by the past, but not stuck in it, we bring the "OG" meta to the modern minecraft ecosystem via an expansive suite of [custom plugins](https://github.com/true-og/OG-Suite). The worlds of TrueOG SMP, which are a continuation of the worlds from OG SMP Season 1, will **never** be reset.

Join our [Discord](https://discord.gg/ma9pMYpBU6) community to connect with us!

You can also follow us on <a rel="me" href="https://mastodon.gamedev.place/@trueog">Mastodon</a>.

TrueOG Network is pre-release software. Our to-do list can be viewed [here](https://true-og.net/todo-list).

With the TrueOG Bootstrap, instead of beginning your minecraft server with a blank folder, you begin with a fully featured SMP and minigames stack, automatically built from source on a wide variety of operating systems. If TrueOG Network has a feature, your server can too, for free, forever.

Our admin team is structured as a unionized, democratic worker cooperative. We dedicte our in-house software to the public domain. This is done in rebellion to OG Network's selfish refusal to share their source code for OG:SMP Season 1, forcing TrueOG to be built from scratch, resulting in a long development period. We oppose TheMisterEpic's financial exploitation of children with pay-to-win gambling elements. As a worker-owned institution, we believe **community matters more than profit.**

---

### **Best operating systems for hosting TrueOG forks:**

- [Devuan Linux](https://devuan.org/) with [OpenRC](https://itsfoss.community/t/switching-init-systems-in-devuan/11819).
- [Void Linux](https://voidlinux.org/) with [runit](https://docs.voidlinux.org/config/services/index.html).

---

**Platforms the TrueOG Bootstrap supports (Bash + pkgsrc capable):**

*Don't see your favorite OS listed? Just ask us on [Discord](https://discord.gg/ma9pMYpBU6) in #plugin-help or submit a pull request to update the platform support chart and we will see what we can do...*

| Platform             | amd64 | aarch64 | armhf | armv7 | riscv64 | ppc64 | ppc64le | mips | sparc64 |
|----------------------|:-----:|:-------:|:-----:|:-----:|:-------:|:-----:|:-------:|:----:|:-------:|
| **NetBSD**           | ✅     | ✅      | ✅    | ✅    | ✅      | ✅    | ✅      | ✅   | ✅      |
| **Linux (glibc)**    | ✅     | ✅      | ✅    | ✅    | ✅      | ✅    | ✅      | ✅   | 🔧¹     |
| **FreeBSD Family**   | ✅     | ✅      | ✅    | ✅    | 🔧²     | ❌³   | ❌³     | ❌³  | ❌³     |
| **OpenBSD**          | ✅     | ✅      | ✅    | ✅    | ❌³     | ❌³   | ❌³     | ❌³  | ❌³     |
| **Solaris Family**   | ✅     | 🚫      | 🚫    | 🚫    | 🚫      | ❌⁴   | ❌⁴     | ❌⁴  | ✅      |
| **macOS**            | ✅     | ✅      | 🚫    | 🚫    | 🚫      | 🚫    | 🚫      | 🚫   | 🚫      |
| **DragonFlyBSD**     | ✅     | 🚫      | 🚫    | 🚫    | 🚫      | 🚫    | 🚫      | 🚫   | 🚫      |
| **Minix**            | ✅     | 🚫      | 🚫    | 🚫    | 🚫      | 🚫    | 🚫      | 🚫   | 🚫      |
| **WSL (Windows)**    | ✅     | 🔧⁵      | 🚫    | 🚫    | 🚫      | 🚫    | 🚫      | 🚫   | 🚫      |
| **Cygwin (Windows)** | ✅     | 🔧⁵      | 🚫    | 🚫    | 🚫      | 🚫    | 🚫      | 🚫   | 🚫      |
| **Android**          | ⚠️     | ⚠️      | ⚠️    | ⚠️    | ⚠️      | 🚫    | 🚫      | 🚫   | 🚫      |
| **iOS**              | ⚠️     | ⚠️      | ⚠️    | ⚠️    | 🚫      | 🚫    | 🚫      | 🚫   | 🚫      |
| **Linux (musl)**     | ❌⁶    | ❌⁶     | ❌⁶   | ❌⁶   | ❌⁶     | ❌⁶   | ❌⁶     | ❌⁶  | ❌⁶     |

---

### Legend

| Symbol | Meaning |
|:------:|:--------|
| ✅ | Native support (bash + pkgsrc bootstrap) |
| ⚠️ | Requires hacking (proot/chroot/jailbreak) |
| 🔧 | Depends on rare hardware or non-standard config |
| ❌ | Platform **exists** but is **not supported** |
| 🚫 | Platform combination **does not exist** |

### To download the full TrueOG Network stack

> git clone https://git.trueog.net/trueog/true-og.git

> cd true-og

> git submodule update --force --recursive --init

### Git Badges

https://intergrav.github.io/devins-badges-docs/badges/cozy/

https://badger.worldwidepixel.ca/

### IDE Plugins for TrueOG Plugin Development

[Eclipse](https://eclipseide.org/) (FOSS) or [MyEclipse](https://www.genuitec.com/products/myeclipse/) (Proprietary):

- AspectJ Development Tools https://marketplace.eclipse.org/content/aspectj-development-tools

- Beyond CVS https://beyondcvs.sourceforge.net/

- Checkstyle https://marketplace.eclipse.org/content/checkstyle-plug

- Enhanced Kotlin https://marketplace.eclipse.org/content/enhanced-kotlin-eclipse

- JSparrow: https://marketplace.eclipse.org/content/jsparrow-java-refactoring-and-java-code-analyzer

- Kotlin https://marketplace.eclipse.org/content/kotlin-plugin-eclipse

- Lombok https://projectlombok.org/setup/eclipse

[IntelliJ IDEA](https://www.jetbrains.com/idea/) (FOSS) or [IntelliJ IDEA Ultimate](https://www.jetbrains.com/idea/buy/?section=personal&billing=monthly) (Proprietary):

- Checkstyle https://plugins.jetbrains.com/plugin/1065-checkstyle-idea

- Classic UI https://plugins.jetbrains.com/plugin/24468-classic-ui

- Lombok https://projectlombok.org/setup/intellij

- Minecraft Development https://plugins.jetbrains.com/plugin/8327-minecraft-development

- Multi Project Workspace https://plugins.jetbrains.com/plugin/24765-multi-project-workspace

### Architectures with Limited or Specialized Support

¹ **Linux on SPARC (glibc)** — pkgsrc builds likely to fail due to missing toolchain components.

² **FreeBSD riscv64** — The kernel runs well on riscv64, but userland packaging is incomplete.

³ **FreeBSD/OpenBSD on POWER, SPARC, or MIPS** — technically possible, but not well supported.

⁴ **Solaris on POWER or MIPS** — No complete runtime environment for that architecture/OS exists.

⁵ **Windows ARM64 (WSL/Cygwin)** — Can run basic Bash environments, but lacks a full POSIX layer.

⁶ **Linux (musl)** — pkgsrc does not play nice with musl.

---

*ad astra per aspera*
